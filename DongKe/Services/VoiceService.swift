import Foundation
import UIKit
import DongKeCore

@MainActor
final class VoiceService {
    static let shared = VoiceService()

    private var coordinator: SpeechCueCoordinator?

    private init() {}

    var isAvailable: Bool {
        coordinator != nil
    }

    func activeCoordinator() -> SpeechCueCoordinator {
        if let coordinator {
            refreshPolicy(isForeground: true)
            return coordinator
        }
        let created = SpeechCueCoordinator(announcer: Self.makeAnnouncer())
        coordinator = created
        refreshPolicy(isForeground: true)
        return created
    }

    func refreshPolicy(isForeground: Bool? = nil) {
        guard let target = coordinator else { return }
        target.policy = SpeechCuePolicy(
            isEnabled: Self.isEnabledByUser,
            isForeground: isForeground ?? (UIApplication.shared.applicationState == .active),
            isVoiceOverRunning: UIAccessibility.isVoiceOverRunning
        )
    }

    func shutdown() {
        coordinator?.stop()
        coordinator = nil
    }

    static var isEnabledByUser: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_VOICE_ENABLED"] == "1" {
            return true
        }
        #endif
        return VoiceSettingsStore.shared.isEnabled
    }

    private static func makeAnnouncer() -> SpeechAnnouncing {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_VOICE_FAKE"] == "1" {
            return FileLoggingAnnouncer()
        }
        #endif
        return SystemSpeechAnnouncer()
    }
}

#if DEBUG
@MainActor
final class FileLoggingAnnouncer: SpeechAnnouncing {
    private let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dk-voice.log")
    private(set) var isSpeaking = false

    func speak(_ text: String) {
        isSpeaking = true
        let line = text + "\n"
        guard let data = line.data(using: .utf8) else { return }
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

    func stop() {
        isSpeaking = false
    }
}
#endif
