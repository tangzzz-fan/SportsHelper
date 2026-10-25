import Foundation

public struct WorkoutCheckpoint: Codable, Equatable, Sendable {
    public var sessionId: UUID
    public var dayIndex: Int
    public var stepIndex: Int
    public var totalSteps: Int
    public var startedAt: Date
    public var updatedAt: Date
    public var restEndsAt: Date?
    public var restTotalSeconds: Int
    public var logs: [SetLog]
    public var steps: [FlowStep]?

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
        steps: [FlowStep]? = nil
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
    }
}

public enum WorkoutResumePolicy {
    public static let window: TimeInterval = 30 * 60

    public static func canResume(_ checkpoint: WorkoutCheckpoint?, now: Date) -> Bool {
        guard let checkpoint else { return false }
        guard checkpoint.totalSteps > 0,
              checkpoint.stepIndex >= 0,
              checkpoint.stepIndex < checkpoint.totalSteps
        else {
            return false
        }
        return now.timeIntervalSince(checkpoint.updatedAt) < window
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
        setIndex: Int,
        plannedValue: Int,
        reason: SkipReason,
        at date: Date
    ) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: prescriptionId,
            catalogId: catalogId,
            setIndex: setIndex,
            status: .skipped,
            plannedValue: plannedValue,
            actualValue: 0,
            skipReason: reason,
            completedAt: date
        )
    }
}
