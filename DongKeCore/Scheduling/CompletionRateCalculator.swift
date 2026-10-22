import Foundation

public enum CompletionRateCalculator {
    public static func dailyRate(completedSets: Int, plannedSets: Int) -> Double? {
        nil
    }

    public static func streak(
        records: [(date: Date, rate: Double?)],
        today: Date,
        calendar: Calendar
    ) -> Int {
        0
    }
}
