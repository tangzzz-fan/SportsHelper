import Foundation
import DongKeCore

/// 当前生效的计划：没导入过就按档案现生成，减载周再叠一层。
///
/// AppShell 和 `WatchIntentInbox` 都要这一份。后者可能在 App 还没建视图时
/// 被 WCSession 唤起，拿不到 `@Environment`，所以不能把这段逻辑留在 View 里。
@MainActor
enum ActivePlanProvider {
    static func raw(planStore: PlanStore, profileStore: ProfileStore) -> WorkoutPlan {
        planStore.plan ?? PlanGenerator.makePlan(profile: profileStore.profile ?? UserProfile())
    }

    static func current(
        planStore: PlanStore,
        profileStore: ProfileStore,
        deloadEnabled: Bool,
        on date: Date = Date()
    ) -> WorkoutPlan {
        DeloadWeek.applied(
            to: raw(planStore: planStore, profileStore: profileStore),
            on: date,
            enabled: deloadEnabled
        )
    }
}
