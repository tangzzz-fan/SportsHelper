import Foundation

public struct PlanProposal: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case dose
        case rebuild
        case swap
        case safety

        public var chineseName: String {
            switch self {
            case .dose: "加量"
            case .rebuild: "重建"
            case .swap: "换动作"
            case .safety: "降量"
            }
        }
    }

    public struct Change: Equatable, Sendable {
        public enum Field: String, Codable, Sendable {
            case sets
            case reps
            case load
            case exercise
        }

        public var itemId: String
        public var name: String
        public var field: Field
        public var fromValue: Int
        public var toValue: Int

        public init(itemId: String, name: String, field: Field, fromValue: Int, toValue: Int) {
            self.itemId = itemId
            self.name = name
            self.field = field
            self.fromValue = fromValue
            self.toValue = toValue
        }

        public var unit: String {
            switch field {
            case .reps: "次"
            case .sets: "组"
            case .load: "%"
            case .exercise: ""
            }
        }

        public var summary: String {
            switch field {
            case .exercise: "\(name) → \(toValue)"
            default: "\(name) \(fromValue) \(unit) → \(toValue) \(unit)"
            }
        }
    }

    public var kind: Kind
    public var changes: [Change]
    public var reason: String
    public var createdAt: Date

    public init(kind: Kind, changes: [Change], reason: String, createdAt: Date) {
        self.kind = kind
        self.changes = changes
        self.reason = reason
        self.createdAt = createdAt
    }

    public var headline: String {
        changes.count == 1 ? changes[0].summary : "\(changes.count) 个动作有变化"
    }

    public var fingerprint: String {
        let parts = changes
            .map { "\($0.itemId):\($0.field.rawValue):\($0.fromValue)>\($0.toValue)" }
            .sorted()
        return (["\(kind.rawValue)"] + parts).joined(separator: "|")
    }
}
