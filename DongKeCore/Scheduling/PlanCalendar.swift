import Foundation

public struct PlanOccurrence: Equatable, Sendable {
    public var dayIndex: Int
    public var date: Date

    public init(dayIndex: Int, date: Date) {
        self.dayIndex = dayIndex
        self.date = date
    }
}

public enum PlanCalendar {
    public static func occurrence(
        on date: Date,
        in plan: WorkoutPlan,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> PlanOccurrence? {
        let today = calendar.startOfDay(for: date)
        if let weekday = Weekday(systemWeekday: calendar.component(.weekday, from: date)),
           let day = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay }) {
            return PlanOccurrence(dayIndex: day.dayIndex, date: today)
        }
        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard let weekday = Weekday(systemWeekday: calendar.component(.weekday, from: candidate)) else { continue }
            guard let day = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay }) else { continue }
            return PlanOccurrence(dayIndex: day.dayIndex, date: candidate)
        }
        return nil
    }

    public static func occurrence(
        of dayIndex: Int,
        anchoredAt date: Date,
        in plan: WorkoutPlan,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> PlanOccurrence? {
        guard let day = plan.days.first(where: { $0.dayIndex == dayIndex && !$0.isRestDay }) else { return nil }
        let anchor = calendar.startOfDay(for: date)
        for offset in [0, -1, 1, -2, 2, -3, 3] {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: anchor) else { continue }
            guard let weekday = Weekday(systemWeekday: calendar.component(.weekday, from: candidate)) else { continue }
            guard weekday == day.weekday else { continue }
            return PlanOccurrence(dayIndex: dayIndex, date: candidate)
        }
        return nil
    }
}
