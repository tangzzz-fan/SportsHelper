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

    @Test("only sessions inside the current week are counted")
    func completedThisWeek() {
        let records = [
            SessionRecordSummary(date: date(19), plannedSets: 9, completedSets: 9),
            SessionRecordSummary(date: date(22), plannedSets: 9, completedSets: 6),
            SessionRecordSummary(date: date(18), plannedSets: 9, completedSets: 9)
        ]
        #expect(HistoryStats.completedThisWeek(records, now: date(22), calendar: calendar) == 2)
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

    @Test("empty history has no streak and no rate")
    func emptyHistory() {
        #expect(HistoryStats.streak([], now: date(22), calendar: calendar) == 0)
        #expect(HistoryStats.completionRate([]) == 0)
    }

    @Test("completion rate weights planned sets, not sessions")
    func completionRateWeightsSets() {
        let records = [
            SessionRecordSummary(date: date(22), plannedSets: 12, completedSets: 9),
            SessionRecordSummary(date: date(21), plannedSets: 9, completedSets: 9)
        ]
        #expect(abs(HistoryStats.completionRate(records) - 18.0 / 21.0) < 0.0001)
    }
}
