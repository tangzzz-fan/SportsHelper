import Foundation
import DongKeCore

struct WorkoutCheckpointStore {
    private let defaults: UserDefaults
    private let key = "dk.workout.checkpoint"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> WorkoutCheckpoint? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WorkoutCheckpoint.self, from: data)
    }

    func save(_ checkpoint: WorkoutCheckpoint) {
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
