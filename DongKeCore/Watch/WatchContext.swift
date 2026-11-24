import Foundation

/// iPhone 经 WCSession 发给 Watch 的展示快照。
///
/// 不再让 Watch 自己读计划/档案：它只有这一份值 + 本地缓存。
/// `checkpoint` 承担「第几步、已完成哪些组、休息到几点」，`exercises`
/// 承担 Watch 需要的展示字段（动作名、总组数、目标文案）。
public struct WatchContext: Codable, Equatable, Sendable {
    public var checkpoint: WorkoutCheckpoint
    public var dayTitle: String
    public var exercises: [String: WatchExerciseInfo]

    public init(
        checkpoint: WorkoutCheckpoint,
        dayTitle: String,
        exercises: [String: WatchExerciseInfo]
    ) {
        self.checkpoint = checkpoint
        self.dayTitle = dayTitle
        self.exercises = exercises
    }

    /// 从 iPhone 的会话快照 + 计划派生。没有 `steps`（老断点）或找不到当天时返回 nil。
    public static func make(checkpoint: WorkoutCheckpoint, plan: WorkoutPlan) -> WatchContext? {
        guard let steps = checkpoint.steps, !steps.isEmpty,
              let day = plan.days.first(where: { $0.dayIndex == checkpoint.dayIndex })
        else {
            return nil
        }
        let flow = WorkoutFlowModel(plan: plan, dayIndex: day.dayIndex)
        var exercises: [String: WatchExerciseInfo] = [:]
        for block in day.blocks {
            for item in block.items {
                exercises[item.itemId] = WatchExerciseInfo(
                    catalogId: item.catalogId,
                    name: item.name,
                    setCount: flow.setCounts[item.itemId] ?? item.sets,
                    targetText: item.target.doseText,
                    restSec: item.restSec
                )
            }
        }
        return WatchContext(checkpoint: checkpoint, dayTitle: day.title, exercises: exercises)
    }

    public var currentStep: FlowStep? {
        guard let steps = checkpoint.steps, steps.indices.contains(checkpoint.stepIndex) else {
            return nil
        }
        return steps[checkpoint.stepIndex]
    }

    public func exercise(for prescriptionId: String) -> WatchExerciseInfo? {
        exercises[prescriptionId]
    }
}

public struct WatchExerciseInfo: Codable, Equatable, Sendable {
    public var catalogId: String
    public var name: String
    public var setCount: Int
    public var targetText: String
    public var restSec: Int

    public init(catalogId: String, name: String, setCount: Int, targetText: String, restSec: Int) {
        self.catalogId = catalogId
        self.name = name
        self.setCount = setCount
        self.targetText = targetText
        self.restSec = restSec
    }
}

public enum WatchSyncKey {
    public static let context = "dk.watch.context"
    public static let log = "dk.watch.log"
    public static let planRevision = "dk.watch.planRevision"
}
