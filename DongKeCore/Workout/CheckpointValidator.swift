import Foundation

public enum CheckpointValidation: Equatable, Sendable {
    case resumable
    case notInProgress
    case planChanged(checkpointRevision: Int, currentRevision: Int)
    case expired
}

public enum CheckpointValidator {
    /// 顺序有意义：已结束 > 计划改版 > 过期。
    /// 计划改版优先于过期，因为用户需要先回 iPhone，时间窗口是不是过了不影响这个判断。
    public static func validate(
        _ checkpoint: WorkoutCheckpoint,
        currentPlanRevision: Int,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CheckpointValidation {
        guard checkpoint.status == .inProgress else {
            return .notInProgress
        }
        guard checkpoint.revision == currentPlanRevision else {
            return .planChanged(
                checkpointRevision: checkpoint.revision,
                currentRevision: currentPlanRevision
            )
        }
        guard WorkoutResumePolicy.canResume(checkpoint, now: now, calendar: calendar) else {
            return .expired
        }
        return .resumable
    }
}
