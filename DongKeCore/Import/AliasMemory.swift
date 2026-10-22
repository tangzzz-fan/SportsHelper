import Foundation

public struct AliasMemory: Equatable, Sendable {
    public static let empty = AliasMemory()

    private var map: [String: String]

    public init(_ pairs: [String: String] = [:]) {
        var normalized: [String: String] = [:]
        for (raw, catalogId) in pairs {
            let key = ExerciseAliasResolver.normalize(raw)
            guard !key.isEmpty, !catalogId.isEmpty else { continue }
            normalized[key] = catalogId
        }
        self.map = normalized
    }

    public var count: Int { map.count }

    public var isEmpty: Bool { map.isEmpty }

    public var pairs: [String: String] { map }

    public mutating func remember(_ rawName: String, catalogId: String) {
        let key = ExerciseAliasResolver.normalize(rawName)
        guard !key.isEmpty, !catalogId.isEmpty else { return }
        map[key] = catalogId
    }

    public func catalogId(for rawName: String) -> String? {
        let key = ExerciseAliasResolver.normalize(rawName)
        guard !key.isEmpty else { return nil }
        return map[key]
    }

    public func merged(with other: AliasMemory) -> AliasMemory {
        var copy = self
        for (key, value) in other.map {
            copy.map[key] = value
        }
        return copy
    }
}
