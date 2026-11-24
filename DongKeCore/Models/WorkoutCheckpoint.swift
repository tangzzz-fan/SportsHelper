import Foundation

public struct WorkoutCheckpoint: Codable, Equatable {
    public let sessionId: UUID
    public let script: [FlowStep]
    public let stepIndex: Int
    public let logs: [SetLog]
    public let revision: Int
    public let status: WorkoutStatus
    public let startedAt: Date
    public let lastUpdatedAt: Date

    public enum WorkoutStatus: String, Codable {
        case inProgress
        case completed
        case abandoned
    }

    public init(
        sessionId: UUID,
        script: [FlowStep],
        stepIndex: Int = 0,
        logs: [SetLog] = [],
        revision: Int = 1,
        status: WorkoutStatus = .inProgress,
        startedAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.script = script
        self.stepIndex = stepIndex
        self.logs = logs
        self.revision = revision
        self.status = status
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    public func stepIndexIsValid(currentPlanRevision: Int) -> Bool {
        return self.revision == currentPlanRevision
    }
}
