import Foundation

public enum DraftSource: String, Sendable {
    case genericJSON
    case markdownTable
    case lineScan
}

public struct DraftItem: Equatable, Sendable {
    public var rawName: String
    public var catalogId: String?
    public var sets: Int?
    public var value: Int?
    public var targetType: SetTargetType?
    public var perSide: Bool
    public var restSec: Int?
    public var assumptions: [String]
    public var origin: String

    public init(
        rawName: String,
        catalogId: String? = nil,
        sets: Int? = nil,
        value: Int? = nil,
        targetType: SetTargetType? = nil,
        perSide: Bool = false,
        restSec: Int? = nil,
        assumptions: [String] = [],
        origin: String = ""
    ) {
        self.rawName = rawName
        self.catalogId = catalogId
        self.sets = sets
        self.value = value
        self.targetType = targetType
        self.perSide = perSide
        self.restSec = restSec
        self.assumptions = assumptions
        self.origin = origin
    }
}

public struct DraftDay: Equatable, Sendable {
    public var order: Int
    public var label: String
    public var weekday: Weekday?
    public var rounds: Int?
    public var items: [DraftItem]

    public init(
        order: Int,
        label: String,
        weekday: Weekday? = nil,
        rounds: Int? = nil,
        items: [DraftItem] = []
    ) {
        self.order = order
        self.label = label
        self.weekday = weekday
        self.rounds = rounds
        self.items = items
    }
}

public struct PlanDraft: Equatable, Sendable {
    public var title: String?
    public var days: [DraftDay]
    public var cautions: [String]
    public var source: DraftSource

    public init(title: String? = nil, days: [DraftDay] = [], cautions: [String] = [], source: DraftSource) {
        self.title = title
        self.days = days
        self.cautions = cautions
        self.source = source
    }

    public var itemCount: Int {
        days.reduce(0) { $0 + $1.items.count }
    }

    public var isEmpty: Bool {
        itemCount == 0
    }
}
