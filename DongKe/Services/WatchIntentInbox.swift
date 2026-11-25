import Foundation
import DongKeCore
import os

private let intentLog = Logger(subsystem: "app.dongke.ios", category: "watch-intent")

/// 手表意图的落点。
///
/// 两条路：
/// - App 有视图（`liveLauncher` 已注册）→ 交给 `AppShell` 裁决并开训练页，
///   用户就在 iPhone 上，看得见
/// - App 被 WCSession 后台唤起 → 没有人注册 launcher，这里自己裁决、落盘、广播。
///   后台没有 UI，所以不能指望 `AppShell.onAppear` 会跑
@MainActor
final class WatchIntentInbox {
    static let shared = WatchIntentInbox()

    var liveLauncher: ((SessionIntent) -> SessionLaunch)?

    private var planStore: PlanStore?
    private var profileStore: ProfileStore?
    private let checkpoints = WorkoutCheckpointStore()

    private init() {}

    func configure(planStore: PlanStore, profileStore: ProfileStore) {
        self.planStore = planStore
        self.profileStore = profileStore
    }

    @discardableResult
    func handle(_ intent: WatchIntent) -> WatchIntentAck {
        guard !intent.isExpired() else {
            intentLog.notice("intent expired kind=\(intent.kind.rawValue, privacy: .public)")
            return WatchIntentAck(outcome: .ignored)
        }
        guard let sessionIntent = intent.sessionIntent, let plan = currentPlan else {
            intentLog.error("intent unusable kind=\(intent.kind.rawValue, privacy: .public)")
            return WatchIntentAck(outcome: .blocked)
        }

        let ack: WatchIntentAck
        if let liveLauncher {
            ack = WatchIntentAck(liveLauncher(sessionIntent))
        } else {
            let launch = SessionLaunchResolver.resolve(
                intent: sessionIntent,
                active: nil,
                stored: checkpoints.load(),
                plan: plan,
                now: Date()
            )
            ack = perform(launch, plan: plan)
        }
        intentLog.notice(
            "intent kind=\(intent.kind.rawValue, privacy: .public) day=\(intent.dayIndex ?? -1, privacy: .public) → \(ack.outcome.rawValue, privacy: .public)"
        )
        return ack
    }

    private var currentPlan: WorkoutPlan? {
        guard let planStore, let profileStore else { return nil }
        return ActivePlanProvider.current(
            planStore: planStore,
            profileStore: profileStore,
            deloadEnabled: DeloadStore.shared.isEnabled
        )
    }

    private func perform(_ launch: SessionLaunch, plan: WorkoutPlan) -> WatchIntentAck {
        switch launch {
        case let .open(sessionId):
            // 没有内存会话却说 open，只可能是断点就是它：补发一份让手表对齐。
            if let stored = checkpoints.load(), stored.sessionId == sessionId {
                broadcast(stored, plan: plan)
            }
            return WatchIntentAck(outcome: .opened)
        case let .resume(checkpoint):
            broadcast(checkpoint, plan: plan)
            return WatchIntentAck(outcome: .resumed)
        case let .create(dayIndex, origin):
            create(dayIndex, plan: plan, origin: origin)
            return WatchIntentAck(outcome: .created)
        case let .abandonAndCreate(abandoned, dayIndex, origin):
            checkpoints.clear()
            try? CheckpointStore.shared.remove(sessionId: abandoned)
            create(dayIndex, plan: plan, origin: origin)
            return WatchIntentAck(outcome: .restarted)
        case let .blocked(block):
            return WatchIntentAck(outcome: .blocked, block: block)
        }
    }

    /// 只写断点，不落 `SessionEntity`——一组都没做，记录页不该多一条空训练。
    private func create(_ dayIndex: Int, plan: WorkoutPlan, origin: SessionOrigin) {
        let occurrence = PlanCalendar.occurrence(of: dayIndex, anchoredAt: Date(), in: plan)
        let session = WorkoutSession(
            plan: plan,
            dayIndex: dayIndex,
            planDate: occurrence?.date,
            origin: origin
        )
        session.checkpointStore = checkpoints
        session.saveCheckpoint()
    }

    private func broadcast(_ checkpoint: WorkoutCheckpoint, plan: WorkoutPlan) {
        guard let context = WatchContext.make(checkpoint: checkpoint, plan: plan) else { return }
        WatchSyncService.shared.send(context)
    }
}
