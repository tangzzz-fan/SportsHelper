import Foundation
import DongKeCore

@MainActor
@Observable
final class VoiceSettingsStore {
    static let shared = VoiceSettingsStore()

    private let levelKey = "dk.voice.level"
    private let legacyKey = "dk.voice.enabled"

    var level: VoiceLevel {
        didSet { UserDefaults.standard.set(level.rawValue, forKey: levelKey) }
    }

    var isEnabled: Bool {
        get { level.isEnabled }
        set { level = newValue ? .standard : .quiet }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: levelKey),
           let saved = VoiceLevel(rawValue: raw) {
            level = saved
            return
        }
        level = UserDefaults.standard.bool(forKey: legacyKey) ? .standard : .quiet
    }
}
