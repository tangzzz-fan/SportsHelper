import Foundation
import UIKit
import DongKeCore

@MainActor
final class VoiceService {
    static let shared = VoiceService()

    private var coordinator: SpeechCueCoordinator?
    private var previewCoordinator: SpeechCueCoordinator?

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPolicy() }
        }
    }

    var isAvailable: Bool {
        coordinator != nil
    }

    static var voiceName: String {
        VoicePicker.bestChinese().name
    }

    static var isEnhancedVoice: Bool {
        VoicePicker.bestChinese().isEnhanced
    }

    func activeCoordinator() -> SpeechCueCoordinator {
        if let coordinator {
            refreshPolicy(isForeground: true)
            return coordinator
        }
        let created = SpeechCueCoordinator(renderer: Self.makeRenderer())
        coordinator = created
        refreshPolicy(isForeground: true)
        return created
    }

    func refreshPolicy(isForeground: Bool? = nil) {
        let policy = SpeechCuePolicy(
            isEnabled: Self.isEnabledByUser,
            isForeground: isForeground ?? (UIApplication.shared.applicationState == .active),
            isVoiceOverRunning: UIAccessibility.isVoiceOverRunning
        )
        coordinator?.policy = policy
    }

    func preview() {
        previewCoordinator?.stop()
        let created = SpeechCueCoordinator(
            policy: SpeechCuePolicy(isEnabled: true, isForeground: true, isVoiceOverRunning: false),
            renderer: Self.makeRenderer()
        )
        previewCoordinator = created
        created.announce(.sessionStart(title: "上肢与核心", exerciseCount: 3, totalSets: 9))
    }

    func shutdown() {
        coordinator?.stop()
        coordinator = nil
        previewCoordinator?.stop()
        previewCoordinator = nil
    }

    static var isEnabledByUser: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_VOICE_ENABLED"] == "1" {
            return true
        }
        #endif
        return VoiceSettingsStore.shared.isEnabled
    }

    private static func makeRenderer() -> SpeechRendering {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_VOICE_FAKE"] == "1" {
            return FileLoggingRenderer()
        }
        #endif
        return SystemSpeechRenderer()
    }
}

#if DEBUG
@MainActor
final class FileLoggingRenderer: SpeechRendering {
    private let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dk-voice.log")

    var availability: SpeechAvailability { .ready }

    var profile: SpeechProfile {
        SpeechProfile(engineId: "file", voiceName: "调试日志", charactersPerSecond: 4.2)
    }

    func prepare() {}

    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void) {
        append(request.text)
        event(.started(request.id))
        event(.finished(request.id, seconds: 0))
    }

    func cancel() {}

    private func append(_ text: String) {
        let data = (text + "\n").data(using: .utf8)
        guard let data else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url)
        }
    }
}
#endif
