import Foundation

@MainActor
@Observable
final class VoiceSettingsStore {
    static let shared = VoiceSettingsStore()

    private let key = "dk.voice.enabled"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: key) }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: key)
    }
}
