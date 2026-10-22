import Foundation
import DongKeCore

struct AliasMemoStore {
    private static let key = "dk.alias.memo"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AliasMemory {
        guard let pairs = defaults.dictionary(forKey: Self.key) as? [String: String] else {
            return .empty
        }
        return AliasMemory(pairs)
    }

    func remember(_ rawName: String, catalogId: String) {
        var memory = load()
        memory.remember(rawName, catalogId: catalogId)
        defaults.set(memory.pairs, forKey: Self.key)
    }

    #if DEBUG
    func reset() {
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
