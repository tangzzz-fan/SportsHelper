import Foundation

public enum CompletionRateCalculator {
    private static let reachedThreshold = 0.8

    public static func dailyRate(completedSets: Int, plannedSets: Int) -> Double? {
        guard plannedSets > 0 else { return nil }
        let raw = Double(max(0, completedSets)) / Double(plannedSets)
        return min(1, max(0, raw))
    }

    public static func streak(
        records: [(date: Date, rate: Double?)],
        today: Date,
        calendar: Calendar
    ) -> Int {
        var reached: [Date: Double] = [:]
        for record in records {
            guard let rate = record.rate, rate >= reachedThreshold else { continue }
            let day = calendar.startOfDay(for: record.date)
            reached[day] = max(reached[day] ?? 0, rate)
        }

        let todayStart = calendar.startOfDay(for: today)
        let cursor: Date
        if reached[todayStart] != nil {
            cursor = todayStart
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
                  reached[yesterday] != nil {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        var probe = cursor
        while reached[probe] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: probe) else { break }
            probe = previous
        }
        return count
    }
}
