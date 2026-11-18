import Foundation
import Testing

@testable import DongKeCore

struct RecordByLoadTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func log(
        _ value: Int,
        load: Load?,
        daysLater: Double = 0,
        sessionId: UUID = UUID()
    ) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "p1",
            catalogId: "squat",
            targetType: .reps,
            setIndex: 1,
            status: .done,
            plannedValue: value,
            actualValue: value,
            actualLoad: load,
            completedAt: day0.addingTimeInterval(daysLater * 86_400)
        )
    }

    private func key(_ loadKey: String) -> RecordKey {
        RecordKey(catalogId: "squat", unit: .reps, loadKey: loadKey)
    }

    @Test func sameExerciseAtTwoLoadsGetsTwoRecords() {
        let records = PersonalRecords.build(logs: [
            log(12, load: Load(type: .dumbbell, value: 8)),
            log(9, load: Load(type: .dumbbell, value: 10), daysLater: 1)
        ])
        #expect(records[key("dumbbell:8")]?.best == 12)
        #expect(records[key("dumbbell:10")]?.best == 9)
    }

    @Test func heavierSetDoesNotOverwriteLighterBest() {
        let records = PersonalRecords.build(logs: [
            log(12, load: Load(type: .dumbbell, value: 8)),
            log(9, load: Load(type: .dumbbell, value: 10), daysLater: 1)
        ])
        #expect(records[key("dumbbell:8")]?.last == 12)
        #expect(records[key("dumbbell:10")]?.last == 9)
    }

    @Test func legacyLogsShareTheUnspecifiedBucket() {
        let records = PersonalRecords.build(logs: [
            log(11, load: nil),
            log(13, load: nil, daysLater: 1)
        ])
        #expect(records[key(RecordKey.unspecifiedLoad)]?.best == 13)
        #expect(records.count == 1)
    }

    @Test func exactLoadWinsOverUnspecified() {
        let records = PersonalRecords.build(logs: [
            log(15, load: nil),
            log(12, load: Load(type: .dumbbell, value: 8))
        ])
        let picked = PersonalRecords.record(
            for: "squat",
            unit: .reps,
            load: Load(type: .dumbbell, value: 8),
            isUsingPrescribedLoad: true,
            in: records
        )
        #expect(picked?.best == 12)
    }

    @Test func fallsBackToUnspecifiedOnlyWhenLoadIsUnchanged() {
        let records = PersonalRecords.build(logs: [log(15, load: nil)])
        let unchanged = PersonalRecords.record(
            for: "squat",
            unit: .reps,
            load: Load(type: .dumbbell, value: 8),
            isUsingPrescribedLoad: true,
            in: records
        )
        #expect(unchanged?.best == 15)

        let changed = PersonalRecords.record(
            for: "squat",
            unit: .reps,
            load: Load(type: .dumbbell, value: 10),
            isUsingPrescribedLoad: false,
            in: records
        )
        #expect(changed == nil)
    }

    @Test func lineTextCarriesWeightWhenKnown() {
        let record = PersonalRecord(last: 10, best: 12)
        #expect(record.lineText(unit: .reps, loadText: "10kg") == "10kg · 上次 10 · 最好 12")
        #expect(record.lineText(unit: .reps) == "上次 10 · 最好 12")
    }

    @Test func celebrationCarriesWeightWhenKnown() {
        #expect(
            RecordCelebration.text(name: "深蹲", value: 12, unit: .reps, loadText: "10kg")
                == "深蹲 10kg 最高纪录 12 个"
        )
        #expect(
            RecordCelebration.text(name: "深蹲", value: 12, unit: .reps)
                == "深蹲最高纪录 12 个"
        )
    }
}
