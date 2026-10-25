import AVFoundation
import DongKeCore

enum VoicePicker {
    struct Choice {
        let voice: AVSpeechSynthesisVoice?
        let name: String
        let isEnhanced: Bool
    }

    private static let cached = pick()

    static func bestChinese() -> Choice {
        cached
    }

    private static func pick() -> Choice {
        let chinese = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "zh-CN" }
        if let best = chinese.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return Choice(
                voice: best,
                name: best.name,
                isEnhanced: best.quality != .default
            )
        }
        let fallback = AVSpeechSynthesisVoice(language: "zh-CN")
        return Choice(voice: fallback, name: fallback?.name ?? "系统默认", isEnhanced: false)
    }
}

@MainActor
final class SystemSpeechRenderer: NSObject, SpeechRendering {
    private let synthesizer = AVSpeechSynthesizer()
    private let choice = VoicePicker.bestChinese()

    private var current: SpeechRequest?
    private var currentUtterance: AVSpeechUtterance?
    private var currentUtteranceID: ObjectIdentifier?
    private var onEvent: ((SpeechOutputEvent) -> Void)?
    private var startedAt: Date?
    private var holdsLease = false
    private var releaseTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
        AudioSessionArbiter.shared.onInterruption { [weak self] in
            self?.cancel()
        }
    }

    var availability: SpeechAvailability {
        .ready
    }

    var profile: SpeechProfile {
        SpeechProfile(
            engineId: "avspeech",
            voiceName: choice.name,
            charactersPerSecond: 4.2
        )
    }

    func prepare() {}

    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void) {
        self.onEvent = event
        current = request
        startedAt = Date()
        acquireLease()

        let utterance = AVSpeechUtterance(string: request.text)
        utterance.voice = choice.voice
        utterance.rate = 0.5
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        currentUtterance = utterance
        currentUtteranceID = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
    }

    func cancel() {
        releaseTask?.cancel()
        releaseTask = nil
        guard let current else {
            releaseLease()
            return
        }
        self.current = nil
        currentUtterance = nil
        currentUtteranceID = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        onEvent?(.cancelled(current.id, .stopped))
        releaseLease()
    }

    private func acquireLease() {
        releaseTask?.cancel()
        releaseTask = nil
        guard holdsLease == false else { return }
        AudioSessionArbiter.shared.borrow(.playback)
        holdsLease = true
    }

    private func scheduleRelease() {
        releaseTask?.cancel()
        releaseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false, current == nil else { return }
            releaseLease()
        }
    }

    private func releaseLease() {
        guard holdsLease else { return }
        holdsLease = false
        AudioSessionArbiter.shared.give(.playback)
    }
}

extension SystemSpeechRenderer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard utteranceID == currentUtteranceID, let current else { return }
            onEvent?(.started(current.id))
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard utteranceID == currentUtteranceID, let current else { return }
            let seconds = startedAt.map { Date().timeIntervalSince($0) } ?? 0
            self.current = nil
            currentUtterance = nil
            currentUtteranceID = nil
            startedAt = nil
            onEvent?(.finished(current.id, seconds: seconds))
            scheduleRelease()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard utteranceID == currentUtteranceID, let current else { return }
            self.current = nil
            currentUtterance = nil
            currentUtteranceID = nil
            startedAt = nil
            onEvent?(.cancelled(current.id, .interrupted))
            scheduleRelease()
        }
    }
}
