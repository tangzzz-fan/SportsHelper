import Foundation

public struct ReminderTrigger: Equatable, Sendable {
    public var weekday: Int
    public var hour: Int
    public var minute: Int

    public init(weekday: Int, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    public static func from(_ spec: ReminderSpec) -> ReminderTrigger {
        ReminderTrigger(
            weekday: spec.weekday.systemWeekday,
            hour: spec.triggerTime.hour,
            minute: spec.triggerTime.minute
        )
    }
}

public enum ReminderPlanBuilder {
    public static func build(
        plan: WorkoutPlan,
        settings: ReminderSettings,
        now: Date
    ) -> [ReminderSpec] {
        Array(WeeklyScheduleGenerator.makeSpecs(plan: plan, settings: settings, now: now).prefix(7))
    }

    public static func identifiers(for plan: WorkoutPlan) -> [String] {
        WeeklyScheduleGenerator
            .makeSpecs(plan: plan, settings: ReminderSettings(), now: Date())
            .map(\.id)
    }
}
