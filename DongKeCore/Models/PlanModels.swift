import Foundation

public enum LoadType: String, Codable, Sendable {
    case bodyweight
    case dumbbell
    case barbell
    case kettlebell
    case band
    case machine
    case other
}

public struct Load: Codable, Equatable, Sendable {
    public var type: LoadType
    public var value: Double

    public init(type: LoadType, value: Double) {
        self.type = type
        self.value = value
    }
}

public struct ExercisePrescription: Codable, Equatable, Identifiable, Sendable {
    public var itemId: String
    public var catalogId: String
    public var name: String
    public var sets: Int
    public var target: SetTarget
    public var restSec: Int
    public var tempo: String
    public var load: Load
    public var notes: String

    public var id: String { itemId }

    public init(
        itemId: String,
        catalogId: String,
        name: String,
        sets: Int,
        target: SetTarget,
        restSec: Int,
        tempo: String = "",
        load: Load = Load(type: .bodyweight, value: 0),
        notes: String = ""
    ) {
        self.itemId = itemId
        self.catalogId = catalogId
        self.name = name
        self.sets = sets
        self.target = target
        self.restSec = restSec
        self.tempo = tempo
        self.load = load
        self.notes = notes
    }
}

public enum BlockKind: String, Codable, Sendable {
    case warmup
    case main
    case circuit
    case superset
    case cooldown
}

public struct ExerciseBlock: Codable, Equatable, Identifiable, Sendable {
    public var blockId: String
    public var kind: BlockKind
    public var title: String
    public var rounds: Int
    public var restBetweenItemsSec: Int
    public var restBetweenRoundsSec: Int
    public var items: [ExercisePrescription]
    public var notes: String

    public var id: String { blockId }

    public init(
        blockId: String,
        kind: BlockKind,
        title: String,
        rounds: Int,
        restBetweenItemsSec: Int,
        restBetweenRoundsSec: Int,
        items: [ExercisePrescription],
        notes: String = ""
    ) {
        self.blockId = blockId
        self.kind = kind
        self.title = title
        self.rounds = rounds
        self.restBetweenItemsSec = restBetweenItemsSec
        self.restBetweenRoundsSec = restBetweenRoundsSec
        self.items = items
        self.notes = notes
    }
}

public struct PlanDay: Codable, Equatable, Identifiable, Sendable {
    public var dayIndex: Int
    public var weekday: Weekday
    public var isRestDay: Bool
    public var title: String
    public var scheduledTime: TimeOfDay?
    public var estimatedMinutes: Int
    public var blocks: [ExerciseBlock]
    public var notes: String

    public var id: Int { dayIndex }

    public init(
        dayIndex: Int,
        weekday: Weekday,
        isRestDay: Bool,
        title: String,
        scheduledTime: TimeOfDay?,
        estimatedMinutes: Int,
        blocks: [ExerciseBlock],
        notes: String = ""
    ) {
        self.dayIndex = dayIndex
        self.weekday = weekday
        self.isRestDay = isRestDay
        self.title = title
        self.scheduledTime = scheduledTime
        self.estimatedMinutes = estimatedMinutes
        self.blocks = blocks
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case dayIndex
        case weekday
        case isRestDay
        case title
        case scheduledTime
        case estimatedMinutes
        case blocks
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayIndex = try container.decode(Int.self, forKey: .dayIndex)
        weekday = try container.decode(Weekday.self, forKey: .weekday)
        isRestDay = try container.decode(Bool.self, forKey: .isRestDay)
        title = try container.decode(String.self, forKey: .title)
        let timeString = try container.decode(String.self, forKey: .scheduledTime)
        scheduledTime = TimeOfDay(string: timeString)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        blocks = try container.decode([ExerciseBlock].self, forKey: .blocks)
        notes = try container.decode(String.self, forKey: .notes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayIndex, forKey: .dayIndex)
        try container.encode(weekday, forKey: .weekday)
        try container.encode(isRestDay, forKey: .isRestDay)
        try container.encode(title, forKey: .title)
        try container.encode(scheduledTime?.stringValue ?? "", forKey: .scheduledTime)
        try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(notes, forKey: .notes)
    }
}

public enum PlanGoal: String, Codable, Sendable, CaseIterable {
    case loseFat = "lose_fat"
    case buildMuscle = "build_muscle"
    case endurance
    case generalFitness = "general_fitness"
    case mobility
}

public extension PlanGoal {
    static let selectable: [PlanGoal] = [.loseFat, .buildMuscle, .endurance, .generalFitness]
}

public enum TrainingLevel: String, Codable, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

public struct PlanMeta: Codable, Equatable, Sendable {
    public var title: String
    public var goal: PlanGoal
    public var level: TrainingLevel
    public var daysPerWeek: Int
    public var sessionMinutes: Int
    public var notes: String

    public init(
        title: String,
        goal: PlanGoal,
        level: TrainingLevel,
        daysPerWeek: Int,
        sessionMinutes: Int,
        notes: String = ""
    ) {
        self.title = title
        self.goal = goal
        self.level = level
        self.daysPerWeek = daysPerWeek
        self.sessionMinutes = sessionMinutes
        self.notes = notes
    }

    public func weeklyTarget(skipped: Int) -> Int {
        max(1, daysPerWeek - skipped)
    }
}

public enum PlanSource: String, Codable, Sendable, CaseIterable {
    case generated
    case ai
    case pasteJSON
    case pasteText
    case manual

    public var isMachineWritten: Bool {
        switch self {
        case .ai, .pasteJSON, .pasteText: true
        case .generated, .manual: false
        }
    }

    public var chineseName: String {
        switch self {
        case .generated: "本地生成"
        case .ai: "AI 生成"
        case .pasteJSON: "导入"
        case .pasteText: "导入"
        case .manual: "手动创建"
        }
    }
}

public struct WorkoutPlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var schemaVersion: Int
    public var meta: PlanMeta
    public var days: [PlanDay]
    public var cautions: [String]
    public var source: PlanSource
    public var revision: Int
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        meta: PlanMeta,
        days: [PlanDay],
        cautions: [String] = [],
        source: PlanSource = .manual,
        revision: Int = 1,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.meta = meta
        self.days = days
        self.cautions = cautions
        self.source = source
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case meta
        case days
        case cautions
        case source
        case revision
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        meta = try container.decode(PlanMeta.self, forKey: .meta)
        days = try container.decode([PlanDay].self, forKey: .days)
        cautions = try container.decode([String].self, forKey: .cautions)
        source = try container.decodeIfPresent(PlanSource.self, forKey: .source) ?? .manual
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(meta, forKey: .meta)
        try container.encode(days, forKey: .days)
        try container.encode(cautions, forKey: .cautions)
        try container.encode(source, forKey: .source)
        try container.encode(revision, forKey: .revision)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

public extension WorkoutPlan {
    func markingSource(
        _ source: PlanSource,
        revision: Int? = nil,
        now: Date = Date()
    ) -> WorkoutPlan {
        var copy = self
        copy.source = source
        if let revision { copy.revision = revision }
        copy.updatedAt = now
        return copy
    }

    var isMachineWritten: Bool {
        source.isMachineWritten
    }
}
