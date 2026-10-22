import Foundation
import DongKeCore

@MainActor
@Observable
final class ReminderSettingsStore {
    static let shared = ReminderSettingsStore()

    private let key = "dk.reminder.settings"

    var settings: ReminderSettings {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ReminderSettings.self, from: data) {
            settings = decoded
        } else {
            settings = ReminderSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
