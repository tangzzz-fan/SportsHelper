import Foundation

public struct WorkoutCheckpoint: Codable, Equatable, Sendable {
    public enum WorkoutStatus: String, Codable, Sendable {
        case inProgress
        case completed
        case abandoned
    }

    public var sessionId: UUID
    public var dayIndex: Int
    public var stepIndex: Int
    public var totalSteps: Int
    public var startedAt: Date
    public var updatedAt: Date
    public var restEndsAt: Date?
    public var restTotalSeconds: Int
    public var logs: [SetLog]
    /// 本次执行序列。老断点没有它时回落计划展开（`WorkoutSession.init`）。
    public var steps: [FlowStep]?
    /// 计划版本号。Watch 侧续练前必须与当前计划比一次，防止拿旧计划继续写日志。
    public var revision: Int
    public var status: WorkoutStatus

    public init(
        sessionId: UUID,
        dayIndex: Int,
        stepIndex: Int,
        totalSteps: Int,
        startedAt: Date,
        updatedAt: Date,
        restEndsAt: Date? = nil,
        restTotalSeconds: Int = 0,
        logs: [SetLog] = [],
        steps: [FlowStep]? = nil,
        revision: Int = 1,
        status: WorkoutStatus = .inProgress
    ) {
        self.sessionId = sessionId
        self.dayIndex = dayIndex
        self.stepIndex = stepIndex
        self.totalSteps = totalSteps
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.restEndsAt = restEndsAt
        self.restTotalSeconds = restTotalSeconds
        self.logs = logs
        self.steps = steps
        self.revision = revision
        self.status = status
    }

    /// `revision` 与 `status` 是 Phase 2 新增字段，老断点里没有。
    /// 手写 `init(from:)` 兜默认值——缺字段不能让整条断点在升级后静默消失。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        dayIndex = try container.decode(Int.self, forKey: .dayIndex)
        stepIndex = try container.decode(Int.self, forKey: .stepIndex)
        totalSteps = try container.decode(Int.self, forKey: .totalSteps)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        restEndsAt = try container.decodeIfPresent(Date.self, forKey: .restEndsAt)
        restTotalSeconds = try container.decodeIfPresent(Int.self, forKey: .restTotalSeconds) ?? 0
        logs = try container.decodeIfPresent([SetLog].self, forKey: .logs) ?? []
        steps = try container.decodeIfPresent([FlowStep].self, forKey: .steps)
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1
        status = try container.decodeIfPresent(WorkoutStatus.self, forKey: .status) ?? .inProgress
    }

    /// Watch 侧续练前的版本检查：计划已改版就不允许继续写旧计划的日志。
    public func matchesRevision(_ currentPlanRevision: Int) -> Bool {
        revision == currentPlanRevision
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case dayIndex
        case stepIndex
        case totalSteps
        case startedAt
        case updatedAt
        case restEndsAt
        case restTotalSeconds
        case logs
        case steps
        case revision
        case status
    }
}

public enum WorkoutResumePolicy {
    /// 旧窗口（30 分钟）。留着是为了让老测试和老文档说清「从哪改过来的」；
    /// 现行规则是「当天都算」，见 `canResume`。
    public static let legacyWindow: TimeInterval = 30 * 60

    /// 当天有效：晚上 19:00 退出，23:59 回来还能接上；跨天算放弃——
    /// 昨天的疲劳账不能记到今天，而且第二天本来就该按当天的状态重新开始。
    public static func canResume(
        _ checkpoint: WorkoutCheckpoint?,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Bool {
        guard let checkpoint else { return false }
        guard checkpoint.totalSteps > 0,
              checkpoint.stepIndex >= 0,
              checkpoint.stepIndex < checkpoint.totalSteps
        else {
            return false
        }
        return calendar.isDate(checkpoint.updatedAt, inSameDayAs: now)
    }

    public static func restState(_ checkpoint: WorkoutCheckpoint, now: Date) -> RestState {
        guard let endAt = checkpoint.restEndsAt, endAt > now, checkpoint.restTotalSeconds > 0 else {
            return .idle
        }
        return .running(endAt: endAt, totalSeconds: checkpoint.restTotalSeconds)
    }
}

extension SetLog {
    public static func skipped(
        sessionId: UUID,
        prescriptionId: String,
        catalogId: String? = nil,
        targetType: SetTargetType? = nil,
        setIndex: Int,
        plannedValue: Int,
        reason: SkipReason?,
        swappedFromCatalogId: String? = nil,
        at date: Date
    ) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: prescriptionId,
            catalogId: catalogId,
            targetType: targetType,
            setIndex: setIndex,
            status: .skipped,
            plannedValue: plannedValue,
            actualValue: 0,
            swappedFromCatalogId: swappedFromCatalogId,
            skipReason: reason,
            completedAt: date
        )
    }
}
