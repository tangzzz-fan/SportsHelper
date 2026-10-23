import Foundation

public struct SessionRecordSummary: Equatable, Sendable {
    public var date: Date
    public var plannedSets: Int
    public var completedSets: Int

    public init(date: Date, plannedSets: Int, completedSets: Int) {
        self.date = date
        self.plannedSets = plannedSets
        self.completedSets = completedSets
    }

    public var isCompleted: Bool {
        plannedSets > 0 && completedSets >= plannedSets
    }
}

public enum HistoryStats {
    public static func rate(_ part: Int, of whole: Int) -> Double? {
        guard whole > 0 else { return nil }
        return min(1, max(0, Double(max(0, part)) / Double(whole)))
    }

    public static func weekStart(for date: Date, calendar: Calendar) -> Date {
        var calendar = calendar
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    public static func completedDaysThisWeek(
        _ records: [SessionRecordSummary],
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        let start = weekStart(for: now, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let days = records
            .filter { $0.isCompleted && $0.date >= start && $0.date < end }
            .map { calendar.startOfDay(for: $0.date) }
        return Set(days).count
    }

    public static func streak(
        _ records: [SessionRecordSummary],
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        let days = Set(records.filter(\.isCompleted).map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
