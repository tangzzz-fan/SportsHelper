import Foundation
import DongKeCore

struct CorrectionStore {
    private static let key = "dk.correction.memory"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CorrectionMemory {
        guard let data = defaults.data(forKey: Self.key),
              let memory = try? JSONDecoder().decode(CorrectionMemory.self, from: data) else {
            return .empty
        }
        return memory
    }

    func remember(catalogId: String, field: CorrectionField, to: Int) {
        var memory = load()
        memory.record(catalogId: catalogId, field: field, to: to)
        save(memory)
    }

    func save(_ memory: CorrectionMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: Self.key)
    }

    #if DEBUG
    func reset() {
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
