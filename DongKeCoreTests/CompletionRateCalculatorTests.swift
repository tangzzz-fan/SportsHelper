import Foundation
import Testing
@testable import DongKeCore

@Suite("CompletionRateCalculator")
struct CompletionRateCalculatorTests {
    @Test func zeroPlannedReturnsNil() {
        #expect(CompletionRateCalculator.dailyRate(completedSets: 0, plannedSets: 0) == nil)
    }

    @Test func fullRate() {
        #expect(CompletionRateCalculator.dailyRate(completedSets: 10, plannedSets: 10) == 1.0)
    }

    @Test func partialRate() {
        #expect(CompletionRateCalculator.dailyRate(completedSets: 5, plannedSets: 10) == 0.5)
    }

    @Test func clampsOvercomplete() {
        #expect(CompletionRateCalculator.dailyRate(completedSets: 12, plannedSets: 10) == 1.0)
    }

    @Test func streakCountsYesterdayWhenTodayUntrained() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let records: [(date: Date, rate: Double?)] = [
            (date: twoDaysAgo, rate: 1.0),
            (date: yesterday, rate: 1.0)
        ]

        #expect(CompletionRateCalculator.streak(records: records, today: today, calendar: calendar) == 2)
    }

    @Test func streakBreaksOnLowRate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let records: [(date: Date, rate: Double?)] = [(date: yesterday, rate: 0.5)]

        #expect(CompletionRateCalculator.streak(records: records, today: today, calendar: calendar) == 0)
    }

    @Test func streakCountsTodayWhenReached() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let records: [(date: Date, rate: Double?)] = [
            (date: yesterday, rate: 1.0),
            (date: today, rate: 0.9)
        ]

        #expect(CompletionRateCalculator.streak(records: records, today: today, calendar: calendar) == 2)
    }
}
