import Foundation

public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case abandoned
}

public struct WorkoutSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var planId: UUID
    public var planDayId: Int
    public var startedAt: Date
    public var finishedAt: Date?
    public var status: SessionStatus
    public var plannedSets: Int
    public var completedSets: Int
    public var totalRestSeconds: Int

    public init(
        id: UUID = UUID(),
        planId: UUID,
        planDayId: Int,
        startedAt: Date,
        finishedAt: Date? = nil,
        status: SessionStatus = .active,
        plannedSets: Int,
        completedSets: Int = 0,
        totalRestSeconds: Int = 0
    ) {
        self.id = id
        self.planId = planId
        self.planDayId = planDayId
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.plannedSets = plannedSets
        self.completedSets = completedSets
        self.totalRestSeconds = totalRestSeconds
    }
}

public enum SetStatus: String, Codable, Sendable {
    case done
    case downgraded
    case skipped
}

public enum SkipReason: String, Codable, Sendable, CaseIterable {
    case noTime
    case tooHard
    case pain
    case noEquipment
    case other
}

public struct SetLog: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var prescriptionId: String
    public var setIndex: Int
    public var status: SetStatus
    public var plannedValue: Int
    public var actualValue: Int
    public var skipReason: SkipReason?
    public var rpe: Int?
    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        prescriptionId: String,
        setIndex: Int,
        status: SetStatus,
        plannedValue: Int,
        actualValue: Int,
        skipReason: SkipReason? = nil,
        rpe: Int? = nil,
        completedAt: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.prescriptionId = prescriptionId
        self.setIndex = setIndex
        self.status = status
        self.plannedValue = plannedValue
        self.actualValue = actualValue
        self.skipReason = skipReason
        self.rpe = rpe
        self.completedAt = completedAt
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
