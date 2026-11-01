import Foundation
import Testing

@testable import DongKeCore

struct WeekHighlightsTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar { Calendar(identifier: .gregorian) }
    private var weekStart: Date { HistoryStats.weekStart(for: now, calendar: calendar) }

    private func log(
        _ value: Int,
        catalogId: String = "squat",
        at offsetDays: Double,
        sessionId: UUID = UUID(),
        setIndex: Int = 1,
        status: SetStatus = .done
    ) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "p\(Int(offsetDays))",
            catalogId: catalogId,
            targetType: .reps,
            setIndex: setIndex,
            status: status,
            plannedValue: 12,
            actualValue: value,
            completedAt: weekStart.addingTimeInterval(offsetDays * 86_400)
        )
    }

    @Test func emptyIsSilent() {
        let highlights = WeekHighlightsBuilder.build(logs: [], now: now, calendar: calendar)
        #expect(highlights.recordsBroken == 0)
        #expect(highlights.headline == nil)
        #expect(highlights.names == nil)
    }

    @Test func beatingLastWeekCounts() {
        let highlights = WeekHighlightsBuilder.build(
            logs: [log(12, at: -1), log(13, at: 0.5)],
            now: now,
            calendar: calendar
        )
        #expect(highlights.recordsBroken == 1)
        #expect(highlights.actions == ["深蹲"])
    }

    @Test func stayingBelowLastWeekDoesNotCount() {
        let highlights = WeekHighlightsBuilder.build(
            logs: [log(15, at: -1), log(12, at: 0.5)],
            now: now,
            calendar: calendar
        )
        #expect(highlights.recordsBroken == 0)
    }

    @Test func tyingDoesNotCount() {
        let highlights = WeekHighlightsBuilder.build(
            logs: [log(12, at: -1), log(12, at: 0.5)],
            now: now,
            calendar: calendar
        )
        #expect(highlights.recordsBroken == 0)
    }

    @Test func firstEverSessionIsNotARecord() {
        let highlights = WeekHighlightsBuilder.build(
            logs: [log(20, at: 0.5)],
            now: now,
            calendar: calendar
        )
        #expect(highlights.recordsBroken == 0)
    }

    @Test func oneActionBreakingTwiceCountsOnce() {
        let session = UUID()
        let highlights = WeekHighlightsBuilder.build(
            logs: [
                log(12, at: -1),
                log(13, at: 0.5, sessionId: session, setIndex: 1),
                log(14, at: 0.5, sessionId: session, setIndex: 2)
            ],
            now: now,
            calendar: calendar
        )
        #expect(highlights.recordsBroken == 1)
    }

    @Test func lastWeekRecordsDoNotLeakIntoThisWeek() {
        let highlights = WeekHighlightsBuilder.build(
            logs: [log(10, at: -8), log(13, at: -1)],
            now: now,
            calendar: calendar
        )
        #expect(highlights.recordsBroken == 0)
    }

    @Test func headlineCountsActionsAndNamesTwoAtMost() {
        let highlights = WeekHighlights(actions: ["深蹲", "俯卧撑", "臀桥"])
        #expect(highlights.headline == "这周 3 个动作破了纪录")
        #expect(highlights.names == "深蹲、俯卧撑")
    }
}
