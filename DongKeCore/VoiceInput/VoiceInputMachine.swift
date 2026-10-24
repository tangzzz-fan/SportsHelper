import Foundation
import Observation

@MainActor
@Observable
public final class VoiceInputMachine {
    public static let maxDuration = VoiceInputLimit.maxDuration
    public static let maxCharacters = VoiceInputLimit.maxCharacters

    public private(set) var phase: VoiceInputPhase = .idle
    public private(set) var transcript: String = ""
    public private(set) var didHitLengthLimit: Bool = false
    public private(set) var elapsedSeconds: TimeInterval = 0
    public private(set) var hasConsentedToOnline: Bool

    @ObservationIgnored private let transcribing: SpeechTranscribing
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let consentRecorder: @MainActor (Bool) -> Void

    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var usesOnDevice = true

    public init(
        transcribing: SpeechTranscribing,
        hasConsentedToOnline: Bool = false,
        now: @escaping @MainActor () -> Date = { Date() },
        consentRecorder: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.transcribing = transcribing
        self.hasConsentedToOnline = hasConsentedToOnline
        self.now = now
        self.consentRecorder = consentRecorder
    }

    public var remainingSeconds: Int {
        max(0, Int((Self.maxDuration - elapsedSeconds).rounded(.up)))
    }

    public var capHint: String {
        didHitLengthLimit
            ? "已到 \(Self.maxCharacters) 字上限，超出部分没记下"
            : VoiceInputCopy.capHint
    }

    public func start() {
        guard phase.isBusy == false else { return }
        transcript = ""
        didHitLengthLimit = false
        elapsedSeconds = 0
        startedAt = nil
        usesOnDevice = true
        phase = .requestingAuthorization
        Task { await resolveAuthorization() }
    }

    public func allowOnline() {
        guard phase == .awaitingOnlineConsent else { return }
        if hasConsentedToOnline == false {
            hasConsentedToOnline = true
            consentRecorder(true)
        }
        usesOnDevice = false
        beginListening()
    }

    public func declineOnline() {
        guard phase == .awaitingOnlineConsent else { return }
        abort(with: .onDeviceUnavailable)
    }

    public func stop() {
        guard phase == .listening else { return }
        transcribing.stop()
        startedAt = nil
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            phase = .failed(.noSpeech)
            return
        }
        transcript = trimmed
        phase = .finished(trimmed)
    }

    public func cancel() {
        transcribing.cancel()
        startedAt = nil
        transcript = ""
        didHitLengthLimit = false
        elapsedSeconds = 0
        phase = .idle
    }

    public func reset() {
        guard phase.isBusy == false else { return }
        cancel()
    }

    public func tick() {
        guard phase == .listening, let startedAt else { return }
        elapsedSeconds = now().timeIntervalSince(startedAt)
        if elapsedSeconds >= Self.maxDuration {
            elapsedSeconds = Self.maxDuration
            stop()
        }
    }

    public func consume() -> String? {
        guard case .finished(let text) = phase else { return nil }
        reset()
        return text
    }

    private func resolveAuthorization() async {
        var status = transcribing.authorization
        if status == .notDetermined {
            status = await transcribing.requestAuthorization()
        }
        guard phase == .requestingAuthorization else { return }
        switch status {
        case .authorized:
            break
        case .notDetermined:
            abort(with: .restricted)
            return
        case .speechDenied:
            abort(with: .speechDenied)
            return
        case .microphoneDenied:
            abort(with: .microphoneDenied)
            return
        case .restricted:
            abort(with: .restricted)
            return
        }
        guard transcribing.supportsOnDeviceRecognition == false else {
            usesOnDevice = true
            beginListening()
            return
        }
        guard hasConsentedToOnline else {
            phase = .awaitingOnlineConsent
            return
        }
        usesOnDevice = false
        beginListening()
    }

    private func beginListening() {
        do {
            try transcribing.start(onDevice: usesOnDevice) { [weak self] event in
                self?.receive(event)
            }
        } catch SpeechTranscriberError.onDeviceUnavailable {
            if usesOnDevice, hasConsentedToOnline {
                usesOnDevice = false
                beginListening()
            } else if usesOnDevice {
                phase = .awaitingOnlineConsent
            } else {
                abort(with: .onDeviceUnavailable)
            }
            return
        } catch SpeechTranscriberError.recognizerUnavailable {
            abort(with: .noRecognizer)
            return
        } catch {
            abort(with: .interrupted)
            return
        }
        startedAt = now()
        elapsedSeconds = 0
        phase = .listening
    }

    private func receive(_ event: SpeechEvent) {
        guard phase == .listening else { return }
        switch event {
        case .partial(let text):
            if let startedAt, now().timeIntervalSince(startedAt) >= Self.maxDuration {
                stop()
                return
            }
            accept(text)
        case .final(let text):
            accept(text)
            stop()
        case .onDeviceUnavailable:
            transcribing.stop()
            startedAt = nil
            guard usesOnDevice else {
                abort(with: .onDeviceUnavailable)
                return
            }
            if hasConsentedToOnline {
                usesOnDevice = false
                beginListening()
            } else {
                phase = .awaitingOnlineConsent
            }
        case .failed:
            abort(with: .interrupted)
        }
    }

    private func accept(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        didHitLengthLimit = trimmed.count > Self.maxCharacters
        transcript = didHitLengthLimit ? String(trimmed.prefix(Self.maxCharacters)) : trimmed
    }

    private func abort(with failure: VoiceInputFailure) {
        transcribing.cancel()
        startedAt = nil
        elapsedSeconds = 0
        phase = .failed(failure)
    }
}
