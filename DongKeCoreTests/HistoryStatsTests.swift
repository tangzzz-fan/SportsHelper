import Testing
import Foundation
@testable import DongKeCore

@Suite("HistoryStats")
struct HistoryStatsTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ day: Int, month: Int = 10, year: Int = 2026, hour: Int = 20) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }

    @Test("week starts on monday")
    func weekStart() {
        let thursday = date(22)
        let start = HistoryStats.weekStart(for: thursday, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        #expect(components.day == 19)
        #expect(components.month == 10)
    }

    @Test("only days completed inside the current week are counted")
    func completedThisWeek() {
        let records = [
            SessionRecordSummary(date: date(19), plannedSets: 9, completedSets: 9),
            SessionRecordSummary(date: date(22), plannedSets: 9, completedSets: 6),
            SessionRecordSummary(date: date(18), plannedSets: 9, completedSets: 9)
        ]
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(22), calendar: calendar) == 1)
    }

    @Test("a half-finished session does not make the week count up")
    func completedThisWeekIgnoresPartial() {
        let records = [
            SessionRecordSummary(date: date(20), plannedSets: 9, completedSets: 8),
            SessionRecordSummary(date: date(21), plannedSets: 9, completedSets: 0)
        ]
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(22), calendar: calendar) == 0)
    }

    @Test("two completed sessions on one day count once for the week")
    func completedThisWeekCountsDays() {
        let records = [
            SessionRecordSummary(date: date(22, hour: 8), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(22, hour: 20), plannedSets: 3, completedSets: 3)
        ]
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(22), calendar: calendar) == 1)
    }

    @Test("streak counts consecutive days ending today")
    func streakEndingToday() {
        let records = [
            SessionRecordSummary(date: date(22), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(21), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(20), plannedSets: 3, completedSets: 3)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 3)
    }

    @Test("streak survives a day that is only recorded for yesterday")
    func streakEndingYesterday() {
        let records = [
            SessionRecordSummary(date: date(21), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(20), plannedSets: 3, completedSets: 3)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 2)
    }

    @Test("a gap breaks the streak")
    func streakBreaks() {
        let records = [
            SessionRecordSummary(date: date(22), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(20), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(19), plannedSets: 3, completedSets: 3)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 1)
    }

    @Test("two sessions on the same day count once for the streak")
    func sameDayCountsOnce() {
        let records = [
            SessionRecordSummary(date: date(22, hour: 8), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(22, hour: 20), plannedSets: 3, completedSets: 3)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 1)
    }

    @Test("a half-finished day does not extend the streak")
    func streakSkipsPartialDays() {
        let records = [
            SessionRecordSummary(date: date(22), plannedSets: 9, completedSets: 6),
            SessionRecordSummary(date: date(21), plannedSets: 3, completedSets: 3),
            SessionRecordSummary(date: date(20), plannedSets: 3, completedSets: 3)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 2)
    }

    @Test("only half-finished days means no streak")
    func partialOnlyDaysHaveNoStreak() {
        let records = [
            SessionRecordSummary(date: date(22), plannedSets: 9, completedSets: 8),
            SessionRecordSummary(date: date(21), plannedSets: 9, completedSets: 4)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 0)
    }

    @Test("a completed session next to a partial one still marks the day")
    func dayCountsWhenAnySessionIsCompleted() {
        let records = [
            SessionRecordSummary(date: date(22, hour: 8), plannedSets: 9, completedSets: 2),
            SessionRecordSummary(date: date(22, hour: 20), plannedSets: 9, completedSets: 9)
        ]
        #expect(HistoryStats.streak(records, now: date(22), calendar: calendar) == 1)
    }

    @Test("empty history has no streak")
    func emptyHistory() {
        #expect(HistoryStats.streak([], now: date(22), calendar: calendar) == 0)
    }

    @Test("rate is nil without a plan and clamped to one")
    func rate() {
        #expect(HistoryStats.rate(0, of: 0) == nil)
        #expect(HistoryStats.rate(10, of: 10) == 1)
        #expect(HistoryStats.rate(5, of: 10) == 0.5)
        #expect(HistoryStats.rate(12, of: 10) == 1)
        #expect(HistoryStats.rate(-3, of: 10) == 0)
    }
}
