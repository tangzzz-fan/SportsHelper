import Foundation

public enum CorrectionField: String, Codable, Sendable, CaseIterable {
    case sets
    case value

    public var chineseName: String {
        switch self {
        case .sets: "组数"
        case .value: "每组量"
        }
    }
}

public struct CorrectionMemory: Codable, Equatable, Sendable {
    public struct Tally: Codable, Equatable, Sendable {
        public var to: Int
        public var count: Int
        public var lastAt: Date

        public init(to: Int, count: Int, lastAt: Date) {
            self.to = to
            self.count = count
            self.lastAt = lastAt
        }
    }

    public struct Applied: Equatable, Sendable {
        public var name: String
        public var catalogId: String
        public var field: CorrectionField
        public var from: Int
        public var to: Int
        public var unit: String
        public var count: Int

        public init(
            name: String,
            catalogId: String,
            field: CorrectionField,
            from: Int,
            to: Int,
            unit: String,
            count: Int
        ) {
            self.name = name
            self.catalogId = catalogId
            self.field = field
            self.from = from
            self.to = to
            self.unit = unit
            self.count = count
        }

        public var assumption: String {
            "\(name) \(field.chineseName) \(from) → \(to)\(unit)（你连着 \(count) 次这么改）"
        }
    }

    public static let threshold = 2
    public static let empty = CorrectionMemory()

    private var tallies: [String: Tally]

    public init(tallies: [String: Tally] = [:]) {
        self.tallies = tallies
    }

    public var count: Int { tallies.count }

    public func tally(for catalogId: String, field: CorrectionField) -> Tally? {
        tallies[Self.key(catalogId, field)]
    }

    public func settled(for catalogId: String, field: CorrectionField) -> Int? {
        guard let tally = tallies[Self.key(catalogId, field)], tally.count >= Self.threshold else { return nil }
        return tally.to
    }

    public mutating func record(
        catalogId: String,
        field: CorrectionField,
        to: Int,
        at: Date = Date()
    ) {
        guard to > 0, ExerciseLibrary.entry(for: catalogId) != nil else { return }
        let key = Self.key(catalogId, field)
        let count = tallies[key]?.to == to ? (tallies[key]?.count ?? 0) + 1 : 1
        tallies[key] = Tally(to: to, count: count, lastAt: at)
    }

    public func applying(to plan: WorkoutPlan) -> (plan: WorkoutPlan, applied: [Applied]) {
        var updated = plan
        var applied: [Applied] = []
        for dayOffset in updated.days.indices {
            for blockOffset in updated.days[dayOffset].blocks.indices {
                for itemOffset in updated.days[dayOffset].blocks[blockOffset].items.indices {
                    let item = updated.days[dayOffset].blocks[blockOffset].items[itemOffset]
                    let unit = Self.unit(for: item.target.type)
                    if let to = settled(for: item.catalogId, field: .sets), to != item.sets {
                        applied.append(Applied(
                            name: item.name,
                            catalogId: item.catalogId,
                            field: .sets,
                            from: item.sets,
                            to: to,
                            unit: " 组",
                            count: tally(for: item.catalogId, field: .sets)?.count ?? Self.threshold
                        ))
                        updated.days[dayOffset].blocks[blockOffset].items[itemOffset].sets = to
                    }
                    if let to = settled(for: item.catalogId, field: .value), to != item.target.value {
                        applied.append(Applied(
                            name: item.name,
                            catalogId: item.catalogId,
                            field: .value,
                            from: item.target.value,
                            to: to,
                            unit: unit,
                            count: tally(for: item.catalogId, field: .value)?.count ?? Self.threshold
                        ))
                        updated.days[dayOffset].blocks[blockOffset].items[itemOffset].target.value = to
                    }
                }
            }
        }
        return (updated, applied)
    }

    public static let disclosureLimit = 4

    public func applying(to draft: ParsedPlanDraft) -> ParsedPlanDraft {
        guard let plan = draft.plan else { return draft }
        let result = applying(to: plan)
        guard result.applied.isEmpty == false else { return draft }

        var seen: Set<String> = []
        var lines: [String] = []
        for applied in result.applied where seen.insert(Self.key(applied.catalogId, applied.field)).inserted {
            lines.append(applied.assumption)
        }
        let disclosed = Array(lines.prefix(Self.disclosureLimit))
        let extra = lines.count - disclosed.count
        let summary = extra > 0 ? ["还有 \(extra) 处按你上次的改法处理了"] : []

        return ParsedPlanDraft(
            plan: result.plan,
            issues: draft.issues,
            rawText: draft.rawText,
            path: draft.path,
            assumptions: disclosed + summary + draft.assumptions,
            unmappedNames: draft.unmappedNames,
            guessedItems: draft.guessedItems
        )
    }

    private static func key(_ catalogId: String, _ field: CorrectionField) -> String {
        "\(catalogId)|\(field.rawValue)"
    }

    private static func unit(for type: SetTargetType) -> String {
        switch type {
        case .reps: " 次"
        case .durationSec: " 秒"
        case .distanceM: " 米"
        }
    }
}
