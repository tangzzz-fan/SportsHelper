import Foundation
import Testing
@testable import DongKeCore

private func makeCheckpoint(
    now: Date = Date(),
    updatedAt: Date? = nil,
    stepIndex: Int = 3,
    totalSteps: Int = 12,
    restEndsAt: Date? = nil,
    restTotal: Int = 90
) -> WorkoutCheckpoint {
    WorkoutCheckpoint(
        sessionId: UUID(),
        dayIndex: 1,
        stepIndex: stepIndex,
        totalSteps: totalSteps,
        startedAt: now.addingTimeInterval(-600),
        updatedAt: updatedAt ?? now,
        restEndsAt: restEndsAt,
        restTotalSeconds: restTotal,
        logs: []
    )
}

@Suite("断点续练")
struct WorkoutResumeTests {
    @Test func freshCheckpointIsResumable() {
        let now = Date()
        #expect(WorkoutResumePolicy.canResume(makeCheckpoint(now: now), now: now))
    }

    @Test func justUnderThirtyMinutesIsResumable() {
        let now = Date()
        let checkpoint = makeCheckpoint(now: now, updatedAt: now.addingTimeInterval(-1799))
        #expect(WorkoutResumePolicy.canResume(checkpoint, now: now))
    }

    @Test func exactlyThirtyMinutesIsNotResumable() {
        let now = Date()
        let checkpoint = makeCheckpoint(now: now, updatedAt: now.addingTimeInterval(-1800))
        #expect(WorkoutResumePolicy.canResume(checkpoint, now: now) == false)
    }

    @Test func finishedStepIndexIsNotResumable() {
        let now = Date()
        let checkpoint = makeCheckpoint(now: now, stepIndex: 12, totalSteps: 12)
        #expect(WorkoutResumePolicy.canResume(checkpoint, now: now) == false)
    }

    @Test func corruptStepIndexIsNotResumable() {
        let now = Date()
        #expect(WorkoutResumePolicy.canResume(makeCheckpoint(now: now, stepIndex: -1), now: now) == false)
        #expect(WorkoutResumePolicy.canResume(makeCheckpoint(now: now, stepIndex: 0, totalSteps: 0), now: now) == false)
    }

    @Test func missingCheckpointIsNotResumable() {
        #expect(WorkoutResumePolicy.canResume(nil, now: Date()) == false)
    }

    @Test func runningRestSurvivesRestore() {
        let now = Date()
        let checkpoint = makeCheckpoint(now: now, restEndsAt: now.addingTimeInterval(42), restTotal: 90)
        guard case let .running(endAt, total) = WorkoutResumePolicy.restState(checkpoint, now: now) else {
            Issue.record("未结束的休息应当恢复成 running")
            return
        }
        #expect(abs(endAt.timeIntervalSince(now) - 42) < 0.001)
        #expect(total == 90)
    }

    @Test func expiredRestRestoresToIdle() {
        let now = Date()
        let checkpoint = makeCheckpoint(now: now, restEndsAt: now.addingTimeInterval(-1))
        #expect(WorkoutResumePolicy.restState(checkpoint, now: now) == .idle)
    }

    @Test func checkpointRoundTripsThroughJSON() throws {
        let checkpoint = makeCheckpoint()
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(WorkoutCheckpoint.self, from: data)
        #expect(decoded == checkpoint)
    }
}

@Suite("跳过本组")
struct SkippedSetLogTests {
    @Test func skipKeepsPlannedValueAndZeroesActual() {
        let log = SetLog.skipped(
            sessionId: UUID(),
            prescriptionId: "i1",
            setIndex: 2,
            plannedValue: 12,
            reason: .noTime,
            at: Date()
        )
        #expect(log.status == .skipped)
        #expect(log.plannedValue == 12)
        #expect(log.actualValue == 0)
        #expect(log.skipReason == .noTime)
        #expect(log.setIndex == 2)
    }

    @Test func skippedSetIsNotCountedAsDone() {
        let sessionId = UUID()
        let logs = [
            SetLog.skipped(sessionId: sessionId, prescriptionId: "i1", setIndex: 1, plannedValue: 10, reason: .pain, at: Date()),
            SetLog(sessionId: sessionId, prescriptionId: "i1", setIndex: 2, status: .done, plannedValue: 10, actualValue: 10, completedAt: Date())
        ]
        let recap = SessionRecap(logs: logs, plannedSets: 2, startedAt: Date(), finishedAt: Date())
        #expect(recap.doneSets == 1)
        #expect(recap.skippedSets == 1)
        #expect(recap.completionRate == 0.5)
    }
}
