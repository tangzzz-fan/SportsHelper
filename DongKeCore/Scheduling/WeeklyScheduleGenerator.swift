import Foundation

public enum WeeklyScheduleGenerator {
    private static let minutesPerDay = 24 * 60

    public static func makeSpecs(
        plan: WorkoutPlan,
        settings: ReminderSettings,
        now: Date
    ) -> [ReminderSpec] {
        guard settings.enabled else { return [] }

        return plan.days.filter { !$0.isRestDay }.compactMap { day in
            let workoutTime = day.scheduledTime ?? settings.defaultTime
            let rawMinutes = workoutTime.minutesSinceMidnight - settings.leadMinutes
            let weekday: Weekday
            let triggerMinutes: Int

            if rawMinutes < 0 {
                triggerMinutes = rawMinutes + minutesPerDay
                weekday = day.weekday.previous
            } else {
                triggerMinutes = rawMinutes % minutesPerDay
                weekday = day.weekday
            }

            guard let triggerTime = TimeOfDay(minutesSinceMidnight: triggerMinutes) else { return nil }

            return ReminderSpec(
                id: "dk.plan.\(plan.id.uuidString).\(weekday.rawValue)",
                weekday: weekday,
                triggerTime: triggerTime,
                workoutTime: workoutTime,
                title: "该练了 · \(day.title)",
                body: "今天 \(exerciseCount(in: day)) 个动作，约 \(day.estimatedMinutes) 分钟",
                kind: .workout
            )
        }
    }

    private static func exerciseCount(in day: PlanDay) -> Int {
        day.blocks.reduce(0) { total, block in
            total + block.items.count * max(1, block.rounds)
        }
    }
}
