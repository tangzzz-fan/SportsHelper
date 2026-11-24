import Foundation

/// 「上次没练完，要不要接着练」什么时候该问。
///
/// 刚记完一组、切出去回条消息再回来，也弹一次选择页只会让人烦。所以三条同时
/// 满足才问：
/// 1. 断点本身还能续——还在进行中、当天之内
/// 2. 至少练过一组（`stepIndex > 0`），否则就是刚开的新会话，没什么好选的
/// 3. 离上次更新超过 `defaultThreshold`
///
/// 另外还在组间休息时不问：那时用户回来该看到的是倒计时，不是一个问句。
///
/// 计划改版的情况不在这里判——改版的阻断由 `CheckpointValidator` 负责，
/// 调用方要先处理它，否则会出现「阻断页」和「续练选择页」同时成立。
public enum ResumePrompt {
    /// 离开多久之后，再打开才值得问一句。
    public static let defaultThreshold: TimeInterval = 10 * 60

    public static func shouldAsk(
        checkpoint: WorkoutCheckpoint,
        currentPlanRevision: Int?,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        threshold: TimeInterval = defaultThreshold
    ) -> Bool {
        guard checkpoint.status == .inProgress else { return false }
        // revision 未知时按「没改版」处理：改版会由 WatchWorkoutView 显示阻断页，
        // 这里只要不抢在它前面问就行。
        if let currentPlanRevision, checkpoint.revision != currentPlanRevision {
            return false
        }
        guard WorkoutResumePolicy.canResume(checkpoint, now: now, calendar: calendar) else {
            return false
        }
        guard checkpoint.stepIndex > 0 else { return false }
        if let restEndsAt = checkpoint.restEndsAt, restEndsAt > now { return false }
        return now.timeIntervalSince(checkpoint.updatedAt) >= threshold
    }
}
