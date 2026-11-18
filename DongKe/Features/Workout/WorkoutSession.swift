import Foundation
import DongKeCore

@MainActor
@Observable
final class WorkoutSession: Identifiable {
    static let maxExtraSets = 3

    let id: UUID
    let plan: WorkoutPlan
    let dayIndex: Int
    let planDate: Date?
    let kind: SessionKind
    let flow: WorkoutFlowModel
    var script: [FlowStep]
    let startedAt: Date
    var store: SessionStore?
    var setLogStore: SetLogStore?
    var checkpointStore: WorkoutCheckpointStore?
    weak var restNotifications: (any RestNotificationScheduling)?

    var stepIndex = 0
    var logs: [SetLog] = []
    /// 用户临时改的重量，按 `itemId` 记忆：同一动作的下一组沿用，换动作回到它自己的处方。
    /// 只在本次会话里有效，不进计划、不写版本。
    var loadOverrides: [String: Double] = [:]
    /// 每个动作上一次实际用的重量。进训练页时预加载一次，让「上次用 10kg」变成这次的默认值，
    /// 用户不用每一组都重新调。
    var lastLoads: [String: Double] = [:]
    var rest: RestState = .idle
    var restKicker = "组间休息"
    var finishedAt: Date?
    /// 结束页那一句判断。`finish` 时算一次，之后不跟着视图刷新重算。
    var narrative: String?
    var restFinishedToken = 0
    var recordCelebration: String?
    var celebratedActions: Set<String> = []
    var voice: WorkoutVoiceSession?
    var setTimer = SetTimerDriver()

    init(
        plan: WorkoutPlan,
        dayIndex: Int,
        planDate: Date? = nil,
        kind: SessionKind = .full,
        store: SessionStore? = nil,
        startedAt: Date = Date(),
        id: UUID = UUID(),
        checkpoint: WorkoutCheckpoint? = nil,
        now: Date = Date()
    ) {
        self.id = id
        self.plan = plan
        self.dayIndex = dayIndex
        self.planDate = planDate
        self.kind = kind
        self.store = store
        self.startedAt = startedAt
        self.flow = WorkoutFlowModel(plan: plan, dayIndex: dayIndex)
        self.script = checkpoint?.steps ?? self.flow.steps

        if let checkpoint {
            let lastIndex = max(0, script.count - 1)
            self.stepIndex = min(max(0, checkpoint.stepIndex), lastIndex)
            self.logs = checkpoint.logs
            self.rest = WorkoutResumePolicy.restState(checkpoint, now: now)

            if case let .set(id, setIndex, _, _) = script[self.stepIndex],
               self.logs.contains(where: { $0.prescriptionId == id && $0.setIndex == setIndex }),
               case .idle = self.rest {
                self.stepIndex = min(self.stepIndex + 1, lastIndex)
            }
        }

        if case .finished? = currentStep {
            finish(now: now)
        }
    }

    var day: PlanDay? {
        plan.days.first(where: { $0.dayIndex == dayIndex })
    }

    var sessionTitle: String {
        day?.title ?? "训练"
    }

    var currentStep: FlowStep? {
        stepIndex < script.count ? script[stepIndex] : nil
    }

    var currentPrescription: ExercisePrescription? {
        guard case let .set(prescriptionId, _, _, _)? = currentStep else { return nil }
        return day?.blocks.flatMap(\.items).first(where: { $0.itemId == prescriptionId })
    }

    var currentSetIndex: Int {
        if case let .set(_, setIndex, _, _)? = currentStep { return setIndex }
        return 1
    }

    var currentSetTotal: Int {
        guard let id = currentPrescription?.itemId else { return 1 }
        return max(flow.setCounts[id] ?? 1, currentSetIndex)
    }

    var currentTarget: SetTarget? {
        guard case let .set(_, _, target, _)? = currentStep else { return nil }
        return target
    }

    /// 当前组该显示的重量。优先级：本会话改过的 > 上次实际用的 > 处方。
    /// 自重且 0kg 返回 nil，训练页不显示重量。
    var currentLoad: Load? {
        guard let item = currentPrescription else { return nil }
        let base = item.load
        guard base.type != .bodyweight || base.value > 0 else { return nil }
        let value = loadOverrides[item.itemId] ?? lastLoads[item.itemId] ?? base.value
        return Load(type: base.type, value: value)
    }

    /// 落库用。和处方一致时记 nil（读的人按处方处理），不一致才写下来。
    var recordedLoad: Load? {
        guard let item = currentPrescription, let current = currentLoad else { return nil }
        return current.value == item.load.value ? nil : current
    }

    /// 当前重量是否就是处方重量。旧日志没有重量时，只有这种情况才允许回落到它们的纪录。
    var isUsingPrescribedLoad: Bool {
        guard let item = currentPrescription else { return true }
        return currentLoad?.value == item.load.value
    }

    func adjustLoad(by delta: Double) {
        guard let item = currentPrescription, let current = currentLoad else { return }
        let next = max(0, current.value + delta)
        loadOverrides[item.itemId] = next == item.load.value ? nil : next
    }

    func resetLoad() {
        guard let item = currentPrescription else { return }
        loadOverrides[item.itemId] = nil
    }

    /// 进训练页时调一次：把每个动作最近一次记住的重量取出来，作为这次的默认值。
    func preloadLastLoads() {
        guard let setLogStore, let day else { return }
        var result: [String: Double] = [:]
        for item in day.blocks.flatMap(\.items) {
            guard item.load.type != .bodyweight || item.load.value > 0 else { continue }
            let logs = setLogStore.logs(forCatalogIds: [item.catalogId], before: startedAt)
            if let load = logs.first(where: { $0.actualLoad != nil })?.actualLoad {
                result[item.itemId] = load.value
            }
        }
        lastLoads = result
    }

    var acceptsBonusReps: Bool {
        currentTarget?.type == .reps
    }

    var isExtraCurrentSet: Bool {
        guard case let .set(id, setIndex, _, _)? = currentStep else { return false }
        return setIndex > (flow.setCounts[id] ?? 0)
    }

    var isLastSetOfItem: Bool {
        guard case let .set(id, setIndex, _, _)? = currentStep else { return false }
        return setIndex == (flow.setCounts[id] ?? 0)
    }

    var extraSetsCompleted: Int {
        logs.filter { $0.origin == .extra }.count
    }

    var canAddExtraSet: Bool {
        guard isResting,
              case let .set(id, setIndex, _, _)? = currentStep else { return false }
        let planned = flow.setCounts[id] ?? 0
        guard planned > 0, setIndex >= planned else { return false }
        guard extraSetsCompleted < WorkoutSession.maxExtraSets else { return false }
        return hasQueuedExtra == false
    }

    var hasQueuedExtra: Bool {
        flow.hasQueuedExtraSet(at: stepIndex, in: script)
    }

    var ledger: SessionLedger {
        SessionLedger(prescribedSets: plannedSets, logs: logs)
    }

    var completedSets: Int {
        ledger.completedSets
    }

    var plannedSets: Int {
        flow.plannedSets
    }

    var progress: Double {
        ledger.completionRate ?? 0
    }

    var isResting: Bool {
        if case .idle = rest { return false }
        return true
    }

    var isFinished: Bool {
        if case .finished? = currentStep { return true }
        return false
    }

    var showsSummary: Bool {
        isFinished || finishedAt != nil
    }

    var recap: SessionRecap {
        SessionRecap(
            ledger: ledger,
            duration: (finishedAt ?? Date()).timeIntervalSince(startedAt)
        )
    }

    func remainingRest(now: Date) -> TimeInterval {
        RestTimerStateMachine.remaining(rest, now: now)
    }

    func totalRestSeconds() -> Int {
        switch rest {
        case .running(_, let total), .paused(_, let total), .finished(let total):
            return total
        case .idle:
            return 0
        }
    }

    var showsSetCountdown: Bool {
        setTimer.showsCountdown
    }

    var setRemainingDisplay: Int {
        setTimer.remainingDisplay
    }

    var setTimerReachedToken: Int {
        setTimer.reachedZeroCount
    }

}
