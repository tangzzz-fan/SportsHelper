import Foundation

public struct DoseContext: Sendable {
    public var plan: WorkoutPlan
    public var logs: [SetLog]
    public var memory: ProposalMemory
    public var sessionStarts: [Date]
    public var asked: Bool
    public var now: Date
    public var calendar: Calendar

    public init(
        plan: WorkoutPlan,
        logs: [SetLog],
        memory: ProposalMemory = .empty,
        sessionStarts: [Date] = [],
        asked: Bool = false,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.plan = plan
        self.logs = logs
        self.memory = memory
        self.sessionStarts = sessionStarts
        self.asked = asked
        self.now = now
        self.calendar = calendar
    }
}
