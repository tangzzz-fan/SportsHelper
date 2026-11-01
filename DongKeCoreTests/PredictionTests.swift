import Foundation
import Testing

@testable import DongKeCore

struct PredictionTests {
    @Test func noHistoryMeansNoPrediction() {
        #expect(Prediction.next(record: PersonalRecord(), unit: .reps, lastRPE: 2) == nil)
    }

    @Test func roomToSpareAddsOneRep() {
        let record = PersonalRecord(last: 12, best: 14, timesDone: 3)
        #expect(Prediction.next(record: record, unit: .reps, lastRPE: 2) == 13)
    }

    @Test func withoutRoomItRepeatsLastTime() {
        let record = PersonalRecord(last: 12, best: 14, timesDone: 3)
        #expect(Prediction.next(record: record, unit: .reps, lastRPE: 3) == 12)
        #expect(Prediction.next(record: record, unit: .reps, lastRPE: nil) == 12)
    }

    @Test func repsStopAtTheCeiling() {
        let record = PersonalRecord(last: 15, best: 15, timesDone: 3)
        #expect(Prediction.next(record: record, unit: .reps, lastRPE: 1) == 15)
    }

    @Test func holdsFollowTheSameAxisAsDoseAdjustment() {
        let record = PersonalRecord(last: 40, best: 40, timesDone: 2)
        #expect(Prediction.next(record: record, unit: .durationSec, lastRPE: 2) == 45)
        #expect(Prediction.next(record: record, unit: .durationSec, lastRPE: 4) == 40)
    }

    @Test func holdsStopAtSixtySeconds() {
        let record = PersonalRecord(last: 58, best: 58, timesDone: 2)
        #expect(Prediction.next(record: record, unit: .durationSec, lastRPE: 1) == 60)
    }

    @Test func distanceIsNotPredicted() {
        let record = PersonalRecord(last: 800, best: 800, timesDone: 1)
        #expect(Prediction.next(record: record, unit: .distanceM, lastRPE: 1) == nil)
    }
}

struct PredictionCalibrationTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar { Calendar(identifier: .gregorian) }
    private var weekStart: Date { HistoryStats.weekStart(for: now, calendar: calendar) }

    private func log(
        predicted: Int?,
        actual: Int,
        daysAgo: Double,
        status: SetStatus = .done,
        unit: SetTargetType = .reps
    ) -> SetLog {
        SetLog(
            sessionId: UUID(),
            prescriptionId: "p\(daysAgo)-\(actual)",
            catalogId: "squat",
            targetType: unit,
            setIndex: 1,
            status: status,
            plannedValue: 12,
            actualValue: actual,
            predictedValue: predicted,
            completedAt: weekStart.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    @Test func noSamplesIsNotPublishable() {
        let report = PredictionCalibrationBuilder.build(logs: [], now: now, calendar: calendar)
        #expect(report.isPublishable == false)
        #expect(report.headline == nil)
    }

    @Test func errorsAreAveragedPerWeek() {
        let logs = [
            log(predicted: 13, actual: 12, daysAgo: 1),
            log(predicted: 13, actual: 11, daysAgo: 2)
        ]
        let report = PredictionCalibrationBuilder.build(logs: logs, now: now, calendar: calendar)
        #expect(report.weeks.count == 1)
        #expect(report.weeks.first?.sampleSize == 2)
        #expect(abs((report.latest ?? 0) - 1.5) < 0.001)
    }

    @Test func needsTwoWeeksAndTwelveSetsToSpeak() {
        var logs: [SetLog] = []
        for index in 0..<6 {
            logs.append(log(predicted: 13, actual: 12, daysAgo: 1 + Double(index) * 0.1))
            logs.append(log(predicted: 12, actual: 12, daysAgo: 8 + Double(index) * 0.1))
        }
        let report = PredictionCalibrationBuilder.build(logs: logs, now: now, calendar: calendar)
        #expect(report.weeks.count == 2)
        #expect(report.sampleSize == 12)
        #expect(report.isPublishable)
        #expect(report.headline != nil)
    }

    @Test func downgradesAndSkipsAreNotGraded() {
        let logs = [
            log(predicted: 13, actual: 12, daysAgo: 1),
            log(predicted: 13, actual: 4, daysAgo: 2, status: .downgraded),
            log(predicted: 13, actual: 0, daysAgo: 3, status: .skipped)
        ]
        let report = PredictionCalibrationBuilder.build(logs: logs, now: now, calendar: calendar)
        #expect(report.weeks.first?.sampleSize == 1)
        #expect(abs((report.latest ?? 0) - 1) < 0.001)
    }

    @Test func oldLogsWithoutPredictionAreIgnored() {
        let logs = [
            log(predicted: nil, actual: 12, daysAgo: 1),
            log(predicted: 12, actual: 12, daysAgo: 2)
        ]
        let report = PredictionCalibrationBuilder.build(logs: logs, now: now, calendar: calendar)
        #expect(report.weeks.first?.sampleSize == 1)
    }

    @Test func unitsAreNotAveragedTogether() {
        let logs = [
            log(predicted: 13, actual: 12, daysAgo: 1),
            log(predicted: 13, actual: 12, daysAgo: 2),
            log(predicted: 45, actual: 40, daysAgo: 3, unit: .durationSec)
        ]
        let report = PredictionCalibrationBuilder.build(logs: logs, now: now, calendar: calendar)
        #expect(report.unit == .reps)
        #expect(abs((report.latest ?? 0) - 1) < 0.001)
    }

    @Test func theCopyOnlyClaimsTheSpanWeActuallyHave() {
        let report = PredictionCalibration(unit: .reps, weeks: [
            .init(start: weekStart.addingTimeInterval(-7 * 86_400), meanAbsoluteError: 2.4, sampleSize: 6),
            .init(start: weekStart, meanAbsoluteError: 0.8, sampleSize: 6)
        ])
        #expect(report.headline?.contains("1 周前") == true)
        #expect(report.headline?.contains("四周") == false)
        #expect(report.headline?.contains("0.8") == true)
    }
}
