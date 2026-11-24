import Foundation
import Testing
@testable import DongKeCore

private let validatorNow = Date(timeIntervalSince1970: 1_770_000_000)

private func validatorCheckpoint(
    revision: Int = 2,
    status: WorkoutCheckpoint.WorkoutStatus = .inProgress,
    stepIndex: Int = 1,
    totalSteps: Int = 6,
    updatedAt: Date = validatorNow
) -> WorkoutCheckpoint {
    WorkoutCheckpoint(
        sessionId: UUID(),
        dayIndex: 1,
        stepIndex: stepIndex,
        totalSteps: totalSteps,
        startedAt: validatorNow.addingTimeInterval(-600),
        updatedAt: updatedAt,
        steps: [.finished],
        revision: revision,
        status: status
    )
}

@Suite("计划版本与断点校验")
struct CheckpointValidatorTests {

    @Test("版本一致、当天、进行中 → 可续")
    func resumable() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .resumable)
    }

    @Test("计划改版 → planChanged，带两边版本号")
    func planChanged() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(revision: 2),
            currentPlanRevision: 3,
            now: validatorNow
        )
        #expect(result == .planChanged(checkpointRevision: 2, currentRevision: 3))
    }

    @Test("训练已完成 → notInProgress")
    func completedIsNotResumable() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(status: .completed),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .notInProgress)
    }

    @Test("训练已放弃 → notInProgress")
    func abandonedIsNotResumable() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(status: .abandoned),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .notInProgress)
    }

    @Test("跨天 → expired")
    func previousDayExpires() {
        let yesterday = validatorNow.addingTimeInterval(-86_400)
        let result = CheckpointValidator.validate(
            validatorCheckpoint(updatedAt: yesterday),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .expired)
    }

    @Test("步序越界 → expired")
    func outOfRangeStepExpires() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(stepIndex: 6, totalSteps: 6),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .expired)
    }

    @Test("没有步骤 → expired")
    func emptyCheckpointExpires() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(stepIndex: 0, totalSteps: 0),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .expired)
    }

    @Test("已结束优先于计划改版")
    func notInProgressWinsOverPlanChange() {
        let result = CheckpointValidator.validate(
            validatorCheckpoint(revision: 1, status: .completed),
            currentPlanRevision: 9,
            now: validatorNow
        )
        #expect(result == .notInProgress)
    }

    @Test("计划改版优先于过期")
    func planChangeWinsOverExpiry() {
        let yesterday = validatorNow.addingTimeInterval(-86_400)
        let result = CheckpointValidator.validate(
            validatorCheckpoint(revision: 1, updatedAt: yesterday),
            currentPlanRevision: 2,
            now: validatorNow
        )
        #expect(result == .planChanged(checkpointRevision: 1, currentRevision: 2))
    }
}
