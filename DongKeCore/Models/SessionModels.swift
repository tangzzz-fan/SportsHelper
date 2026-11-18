import Foundation

public enum SetStatus: String, Codable, Sendable {
    case done
    case downgraded
    case skipped
}

public enum SetOrigin: String, Codable, Sendable {
    case prescribed
    case extra
}

/// 这一次会话是完整版还是当天压缩出来的短版。短版算「练过」，只在记录标题上标出来。
public enum SessionKind: String, Codable, Sendable {
    case full
    case short
}

public enum SkipReason: String, Codable, Sendable, CaseIterable {
    case noTime
    case tooHard
    case pain
    case noEquipment
    case other

    public var chineseName: String {
        switch self {
        case .noTime: "没时间"
        case .tooHard: "太累"
        case .pain: "疼"
        case .noEquipment: "没器械"
        case .other: "其他"
        }
    }
}

public struct SetLog: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var prescriptionId: String
    public var catalogId: String?
    public var targetType: SetTargetType?
    public var setIndex: Int
    public var status: SetStatus
    public var plannedValue: Int
    public var actualValue: Int
    /// 这一组实际用的重量。nil 表示「按处方」，与 `planDate` 的回落同构：
    /// 旧日志没有这个字段时，读的人按处方重量处理，而不是当成 0kg。
    public var actualLoad: Load?
    /// 这一组是换过动作之后做的：值是换之前的 `catalogId`。
    /// 剂量按原动作归肌群，纪录按新动作算——两件事各归各处。
    public var swappedFromCatalogId: String?
    public var predictedValue: Int?
    public var skipReason: SkipReason?
    public var rpe: Int?
    public var completedAt: Date
    public var origin: SetOrigin

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        prescriptionId: String,
        catalogId: String? = nil,
        targetType: SetTargetType? = nil,
        setIndex: Int,
        status: SetStatus,
        plannedValue: Int,
        actualValue: Int,
        actualLoad: Load? = nil,
        swappedFromCatalogId: String? = nil,
        predictedValue: Int? = nil,
        skipReason: SkipReason? = nil,
        rpe: Int? = nil,
        completedAt: Date,
        origin: SetOrigin = .prescribed
    ) {
        self.id = id
        self.sessionId = sessionId
        self.prescriptionId = prescriptionId
        self.catalogId = catalogId
        self.targetType = targetType
        self.setIndex = setIndex
        self.status = status
        self.plannedValue = plannedValue
        self.actualValue = actualValue
        self.actualLoad = actualLoad
        self.swappedFromCatalogId = swappedFromCatalogId
        self.predictedValue = predictedValue
        self.skipReason = skipReason
        self.rpe = rpe
        self.completedAt = completedAt
        self.origin = origin
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case prescriptionId
        case catalogId
        case targetType
        case setIndex
        case status
        case plannedValue
        case actualValue
        case actualLoad
        case swappedFromCatalogId
        case predictedValue
        case skipReason
        case rpe
        case completedAt
        case origin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        prescriptionId = try container.decode(String.self, forKey: .prescriptionId)
        catalogId = try container.decodeIfPresent(String.self, forKey: .catalogId)
        targetType = try container.decodeIfPresent(SetTargetType.self, forKey: .targetType)
        setIndex = try container.decode(Int.self, forKey: .setIndex)
        status = try container.decode(SetStatus.self, forKey: .status)
        plannedValue = try container.decode(Int.self, forKey: .plannedValue)
        actualValue = try container.decode(Int.self, forKey: .actualValue)
        actualLoad = (try? container.decodeIfPresent(Load.self, forKey: .actualLoad)) ?? nil
        swappedFromCatalogId = try container.decodeIfPresent(String.self, forKey: .swappedFromCatalogId)
        predictedValue = try container.decodeIfPresent(Int.self, forKey: .predictedValue)
        skipReason = try container.decodeIfPresent(SkipReason.self, forKey: .skipReason)
        rpe = try container.decodeIfPresent(Int.self, forKey: .rpe)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
            .flatMap(SetOrigin.init(rawValue:)) ?? .prescribed
    }
}

public struct ReminderSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var leadMinutes: Int
    public var soundEnabled: Bool
    public var defaultTime: TimeOfDay

    public init(
        enabled: Bool = true,
        leadMinutes: Int = 5,
        soundEnabled: Bool = true,
        defaultTime: TimeOfDay = TimeOfDay(hour: 20, minute: 30)
    ) {
        self.enabled = enabled
        self.leadMinutes = leadMinutes
        self.soundEnabled = soundEnabled
        self.defaultTime = defaultTime
    }
}

public enum ReminderKind: String, Codable, Sendable {
    case workout
}

public struct ReminderSpec: Equatable, Identifiable, Sendable {
    public var id: String
    public var weekday: Weekday
    public var triggerTime: TimeOfDay
    public var workoutTime: TimeOfDay
    public var title: String
    public var body: String
    public var kind: ReminderKind

    public init(
        id: String,
        weekday: Weekday,
        triggerTime: TimeOfDay,
        workoutTime: TimeOfDay,
        title: String,
        body: String,
        kind: ReminderKind = .workout
    ) {
        self.id = id
        self.weekday = weekday
        self.triggerTime = triggerTime
        self.workoutTime = workoutTime
        self.title = title
        self.body = body
        self.kind = kind
    }
}
