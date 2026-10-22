import Foundation
import DongKeCore

@MainActor
@Observable
final class WorkoutSession: Identifiable {
    let id: UUID
    let plan: WorkoutPlan
    let dayIndex: Int
    let flow: WorkoutFlowModel
    let startedAt: Date
    var store: SessionStore?
    var setLogStore: SetLogStore?
    var checkpointStore: WorkoutCheckpointStore?
    weak var restNotifications: (any RestNotificationScheduling)?

    private(set) var stepIndex = 0
    private(set) var logs: [SetLog] = []
    private(set) var rest: RestState = .idle
    private(set) var restKicker = "组间休息"
    private(set) var finishedAt: Date?
    private(set) var restFinishedToken = 0

    init(
        plan: WorkoutPlan,
        dayIndex: Int,
        store: SessionStore? = nil,
        startedAt: Date = Date(),
        id: UUID = UUID(),
        checkpoint: WorkoutCheckpoint? = nil,
        now: Date = Date()
    ) {
        self.id = id
        self.plan = plan
        self.dayIndex = dayIndex
        self.store = store
        self.startedAt = startedAt
        self.flow = WorkoutFlowModel(plan: plan, dayIndex: dayIndex)

        if let checkpoint {
            let lastIndex = max(0, flow.steps.count - 1)
            self.stepIndex = min(max(0, checkpoint.stepIndex), lastIndex)
            self.logs = checkpoint.logs
            self.rest = WorkoutResumePolicy.restState(checkpoint, now: now)
        }
    }

    var day: PlanDay? {
        plan.days.first(where: { $0.dayIndex == dayIndex })
    }

    var sessionTitle: String {
        day?.title ?? "训练"
    }

    var currentStep: FlowStep? {
        stepIndex < flow.steps.count ? flow.steps[stepIndex] : nil
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
        currentPrescription?.sets ?? 1
    }

    var completedSets: Int {
        logs.filter { $0.status != .skipped }.count
    }

    var plannedSets: Int {
        flow.plannedSets
    }

    var progress: Double {
        guard plannedSets > 0 else { return 0 }
        return min(1, Double(completedSets) / Double(plannedSets))
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
            logs: logs,
            plannedSets: plannedSets,
            startedAt: startedAt,
            finishedAt: finishedAt ?? Date()
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

    func completeSet(now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec)? = currentStep else {
            advance()
            return
        }
        appendLog(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            status: .done,
            plannedValue: target.value,
            actualValue: target.value,
            completedAt: now
        ), now: now)
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func downgradeSet(now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec)? = currentStep else {
            advance()
            return
        }
        appendLog(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            status: .downgraded,
            plannedValue: target.value,
            actualValue: max(1, target.value / 2),
            skipReason: .tooHard,
            completedAt: now
        ), now: now)
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func skipSet(reason: SkipReason = .noTime, now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, _)? = currentStep else {
            advance()
            return
        }
        appendLog(.skipped(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            plannedValue: target.value,
            reason: reason,
            at: now
        ), now: now)
        advance()
        saveCheckpoint(now: now)
    }

    func refresh(now: Date = Date()) {
        var effects: [RestEffect] = []
        let next = RestTimerStateMachine.reduce(rest, .tick(now: now), &effects)
        if next != rest { rest = next }
        if effects.contains(.playHaptic) {
            restFinishedToken += 1
        }
        if effects.contains(.autoAdvanceToNextSet) {
            rest = .idle
            advance()
            saveCheckpoint(now: now)
        }
    }

    func extendRest(by seconds: Int = 15, now: Date = Date()) {
        var effects: [RestEffect] = []
        rest = RestTimerStateMachine.reduce(rest, .extend(seconds: seconds, now: now), &effects)
        saveCheckpoint(now: now)
    }

    func togglePauseRest(now: Date = Date()) {
        var effects: [RestEffect] = []
        switch rest {
        case .running:
            rest = RestTimerStateMachine.reduce(rest, .pause(now: now), &effects)
        case .paused:
            rest = RestTimerStateMachine.reduce(rest, .resume(now: now), &effects)
        default:
            break
        }
        saveCheckpoint(now: now)
    }

    func skipRest(now: Date = Date()) {
        rest = .idle
        advance()
        saveCheckpoint(now: now)
    }

    func endWorkout() {
        rest = .idle
        finish(now: Date())
    }

    private func finish(now: Date) {
        guard finishedAt == nil else { return }
        finishedAt = now
        persist(finishedAt: now)
        saveCheckpoint(now: now)
    }

    private func appendLog(_ log: SetLog, now: Date) {
        logs.append(log)
        setLogStore?.add(log)
        persist()
        saveCheckpoint(now: now)
    }

    private func saveCheckpoint(now: Date = Date()) {
        syncRestNotification()
        guard let checkpointStore else { return }
        guard finishedAt == nil else {
            checkpointStore.clear()
            return
        }
        var restEndsAt: Date?
        var restTotal = 0
        if case let .running(endAt, total) = rest {
            restEndsAt = endAt
            restTotal = total
        }
        checkpointStore.save(WorkoutCheckpoint(
            sessionId: id,
            dayIndex: dayIndex,
            stepIndex: stepIndex,
            totalSteps: flow.steps.count,
            startedAt: startedAt,
            updatedAt: now,
            restEndsAt: restEndsAt,
            restTotalSeconds: restTotal,
            logs: logs
        ))
    }

    private func persist(finishedAt: Date? = nil) {
        store?.upsert(
            id: id,
            title: sessionTitle,
            plannedSets: plannedSets,
            completedSets: completedSets,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    private func beginRestIfNeeded(seconds: Int, kicker: String, now: Date) {
        if case .finished? = nextStep {
            advance()
            return
        }
        guard seconds > 0 else {
            advance()
            return
        }
        startRest(seconds: seconds, kicker: kicker, now: now)
    }

    private var nextStep: FlowStep? {
        stepIndex + 1 < flow.steps.count ? flow.steps[stepIndex + 1] : nil
    }

    private func startRest(seconds: Int, kicker: String, now: Date) {
        restKicker = kicker
        var effects: [RestEffect] = []
        rest = RestTimerStateMachine.reduce(rest, .start(seconds: seconds, now: now), &effects)
        saveCheckpoint(now: now)
    }

    private func syncRestNotification() {
        guard let restNotifications else { return }
        if case let .running(endAt, _) = rest {
            restNotifications.scheduleRestEnd(
                dayIndex: dayIndex,
                sessionId: id,
                endsAt: endAt,
                nextTitle: restKicker
            )
        } else {
            restNotifications.cancelRestEnd()
        }
    }

    private func advance() {
        rest = .idle
        guard stepIndex + 1 < flow.steps.count else {
            saveCheckpoint()
            return
        }
        stepIndex += 1
        autoStartRestIfBreak(now: Date())
        saveCheckpoint()
    }

    private func autoStartRestIfBreak(now: Date) {
        switch currentStep {
        case let .roundBreak(seconds)?:
            startRest(seconds: seconds, kicker: "回合休息", now: now)
        case let .blockBreak(seconds, nextTitle)?:
            startRest(seconds: seconds, kicker: "下一项 · \(nextTitle)", now: now)
        case .finished?:
            finish(now: now)
        default:
            break
        }
    }
}
