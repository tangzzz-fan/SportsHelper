import Foundation
import Testing

@testable import DongKeCore

struct PersonalRecordsTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func log(
        _ value: Int,
        catalogId: String? = "squat",
        targetType: SetTargetType? = .reps,
        status: SetStatus = .done,
        origin: SetOrigin = .prescribed,
        setIndex: Int = 1,
        sessionId: UUID = UUID(),
        daysLater: Double = 0
    ) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "p1",
            catalogId: catalogId,
            targetType: targetType,
            setIndex: setIndex,
            status: status,
            plannedValue: value,
            actualValue: value,
            completedAt: day0.addingTimeInterval(daysLater * 86_400),
            origin: origin
        )
    }

    private var key: RecordKey { RecordKey(catalogId: "squat", unit: .reps) }

    @Test func emptyHistoryIsEmpty() {
        #expect(PersonalRecords.build(logs: []).isEmpty)
    }

    @Test func lastAndBestComeFromDifferentSessions() {
        let a = UUID()
        let b = UUID()
        let records = PersonalRecords.build(logs: [
            log(14, sessionId: a, daysLater: 0),
            log(9, sessionId: b, daysLater: 1)
        ])
        let record = records[key]
        #expect(record?.best == 14)
        #expect(record?.last == 9)
        #expect(record?.timesDone == 2)
    }

    @Test func lastTakesOneSessionNotOneSet() {
        let session = UUID()
        let records = PersonalRecords.build(logs: [
            log(10, setIndex: 1, sessionId: session),
            log(13, setIndex: 2, sessionId: session)
        ])
        #expect(records[key]?.last == 13)
        #expect(records[key]?.timesDone == 1)
    }

    @Test func downgradedCountsAsLastButNeverAsBest() {
        let session = UUID()
        let records = PersonalRecords.build(logs: [
            log(12, sessionId: UUID(), daysLater: 0),
            log(4, status: .downgraded, sessionId: session, daysLater: 1)
        ])
        #expect(records[key]?.best == 12)
        #expect(records[key]?.last == 4)
        #expect(records[key]?.timesDone == 1)
    }

    @Test func skippedIsIgnoredEntirely() {
        let records = PersonalRecords.build(logs: [
            log(12, sessionId: UUID(), daysLater: 0),
            log(0, status: .skipped, sessionId: UUID(), daysLater: 1)
        ])
        #expect(records[key]?.best == 12)
        #expect(records[key]?.last == 12)
        #expect(records[key]?.timesDone == 1)
    }

    @Test func extraSetsCount() {
        let records = PersonalRecords.build(logs: [
            log(10, sessionId: UUID()),
            log(15, origin: .extra, sessionId: UUID(), daysLater: 1)
        ])
        #expect(records[key]?.best == 15)
    }

    @Test func logsWithoutCatalogIdAreInvisible() {
        let records = PersonalRecords.build(logs: [
            log(20, catalogId: nil),
            log(8, catalogId: "squat")
        ])
        #expect(records.count == 1)
        #expect(records[key]?.best == 8)
    }

    @Test func beforeExcludesTheCurrentSet() {
        let earlier = log(12, sessionId: UUID(), daysLater: 0)
        let current = log(13, sessionId: UUID(), daysLater: 1)
        let records = PersonalRecords.build(logs: [earlier, current], before: current.completedAt)
        #expect(records[key]?.best == 12)
        #expect(records[key]?.last == 12)
    }

    @Test func unitSplitsRecordsOfTheSameAction() {
        let records = PersonalRecords.build(logs: [
            log(12, targetType: .reps),
            log(45, targetType: .durationSec, daysLater: 1)
        ])
        #expect(records.count == 2)
        #expect(records[RecordKey(catalogId: "squat", unit: .reps)]?.best == 12)
        #expect(records[RecordKey(catalogId: "squat", unit: .durationSec)]?.best == 45)
    }

    @Test func legacyLogsInferTheUnitFromTheLibrary() {
        let records = PersonalRecords.build(logs: [
            log(40, catalogId: "plank", targetType: nil)
        ])
        #expect(records[RecordKey(catalogId: "plank", unit: .durationSec)]?.best == 40)
        #expect(records[RecordKey(catalogId: "plank", unit: .reps)] == nil)
    }

    @Test func duplicatesOfTheSameSetDoNotCountTwice() {
        let session = UUID()
        let duplicated = log(12, sessionId: session)
        let records = PersonalRecords.build(logs: [duplicated, duplicated])
        #expect(records[key]?.timesDone == 1)
    }

    @Test func lineShowsBothNumbersWhenTheyDiffer() {
        let record = PersonalRecord(last: 10, best: 12, timesDone: 3)
        #expect(record.lineText(unit: .reps) == "上次 10 · 最好 12")
    }

    @Test func lineKeepsBothNumbersWhenTheyMatch() {
        let record = PersonalRecord(last: 10, best: 10, timesDone: 1)
        #expect(record.lineText(unit: .reps) == "上次 10 · 最好 10")
    }

    @Test func lineDropsBestWhenOnlyDowngradesHappened() {
        let record = PersonalRecord(last: 4, best: nil, timesDone: 0)
        #expect(record.lineText(unit: .reps) == "上次 4")
    }

    @Test func lineIsNilWithoutHistory() {
        #expect(PersonalRecord().lineText(unit: .reps) == nil)
    }

    @Test func lineCarriesTheUnit() {
        let hold = PersonalRecord(last: 40, best: 45, timesDone: 2)
        #expect(hold.lineText(unit: .durationSec) == "上次 40 秒 · 最好 45 秒")
        let walk = PersonalRecord(last: 800, best: 1200, timesDone: 1)
        #expect(walk.lineText(unit: .distanceM) == "上次 800 米 · 最好 1200 米")
    }

    @Test func celebrationNamesTheActionAndTheNumber() {
        #expect(RecordCelebration.text(name: "深蹲", value: 13, unit: .reps) == "深蹲最高纪录 13 个")
        #expect(RecordCelebration.text(name: "平板支撑", value: 48, unit: .durationSec) == "平板支撑最长 48 秒")
    }

    @Test func celebrationIsSilentForDistance() {
        #expect(RecordCelebration.text(name: "农夫行走", value: 800, unit: .distanceM) == nil)
    }

    @Test func gateNeedsAHistoryToBeat() {
        #expect(RecordGate.isRecord(best: nil, actual: 13) == false)
    }

    @Test func gateIsStrictlyGreater() {
        #expect(RecordGate.isRecord(best: 12, actual: 13))
        #expect(RecordGate.isRecord(best: 12, actual: 12) == false)
        #expect(RecordGate.isRecord(best: 12, actual: 11) == false)
    }
}
