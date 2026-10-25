import Foundation

public struct PlanProposal: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case dose
        case rebuild
        case swap
        case safety

        public var chineseName: String {
            switch self {
            case .dose: "剂量"
            case .rebuild: "重建"
            case .swap: "换动作"
            case .safety: "保护"
            }
        }
    }

    public struct Change: Equatable, Sendable {
        public enum Field: String, Codable, Sendable {
            case sets
            case reps
            case hold
            case load
            case exercise
        }

        public var itemId: String
        public var name: String
        public var field: Field
        public var fromValue: Double
        public var toValue: Double
        public var toName: String?
        public var toId: String?

        public init(
            itemId: String,
            name: String,
            field: Field,
            fromValue: Double,
            toValue: Double,
            toName: String? = nil,
            toId: String? = nil
        ) {
            self.itemId = itemId
            self.name = name
            self.field = field
            self.fromValue = fromValue
            self.toValue = toValue
            self.toName = toName
            self.toId = toId
        }

        public var unit: String {
            switch field {
            case .reps: "次"
            case .hold: "秒"
            case .sets: "组"
            case .load: "kg"
            case .exercise: ""
            }
        }

        public var summary: String {
            if field == .exercise {
                return "\(name) → \(toName ?? "换一个")"
            }
            return "\(name) \(number(fromValue)) \(unit) → \(number(toValue)) \(unit)"
        }

        public var isReduction: Bool {
            field == .exercise ? false : toValue < fromValue
        }

        private func number(_ value: Double) -> String {
            value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        }
    }

    public var kind: Kind
    public var changes: [Change]
    public var droppedItemIds: [String]
    public var reason: String
    public var createdAt: Date
    public var isDeload: Bool

    public init(
        kind: Kind,
        changes: [Change],
        droppedItemIds: [String] = [],
        reason: String,
        createdAt: Date,
        isDeload: Bool = false
    ) {
        self.kind = kind
        self.changes = changes
        self.droppedItemIds = droppedItemIds
        self.reason = reason
        self.createdAt = createdAt
        self.isDeload = isDeload
    }

    public var headline: String {
        if changes.count == 1, droppedItemIds.isEmpty {
            return changes[0].summary
        }
        if changes.isEmpty == false, droppedItemIds.isEmpty == false {
            return "\(changes.count) 个动作变轻，去掉 \(droppedItemIds.count) 个"
        }
        if changes.isEmpty, droppedItemIds.isEmpty == false {
            return "去掉 \(droppedItemIds.count) 个动作"
        }
        return "\(changes.count) 个动作有变化"
    }

    public var isReduction: Bool {
        if droppedItemIds.isEmpty == false { return true }
        return changes.isEmpty == false && changes.allSatisfy(\.isReduction)
    }

    public var fields: Set<Change.Field> {
        Set(changes.map(\.field))
    }

    public var fingerprint: String {
        let changeParts = changes
            .map { "\($0.itemId):\($0.field.rawValue):\($0.fromValue)>\($0.toValue)" }
            .sorted()
        let dropParts = droppedItemIds.sorted().map { "\($0):drop" }
        return (["\(kind.rawValue)"] + changeParts + dropParts).joined(separator: "|")
    }
}
