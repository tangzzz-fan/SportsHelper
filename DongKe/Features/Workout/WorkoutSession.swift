import Foundation
import DongKeCore

@MainActor
@Observable
final class WorkoutSession: Identifiable {
    let id = UUID()
    let plan: WorkoutPlan
    let dayIndex: Int
    let flow: WorkoutFlowModel
    let startedAt = Date()
    var store: SessionStore?

    private(set) var stepIndex = 0
    private(set) var logs: [SetLog] = []
    private(set) var rest: RestState = .idle
    private(set) var restKicker = "组间休息"

    var onFinish: (() -> Void)?

    init(plan: WorkoutPlan, dayIndex: Int, store: SessionStore? = nil) {
        self.plan = plan
        self.dayIndex = dayIndex
        self.store = store
        self.flow = WorkoutFlowModel(plan: plan, dayIndex: dayIndex)
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
        logs.append(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            status: .done,
            plannedValue: target.value,
            actualValue: target.value,
            completedAt: now
        ))
        persist()
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func downgradeSet(now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec)? = currentStep else {
            advance()
            return
        }
        logs.append(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            status: .downgraded,
            plannedValue: target.value,
            actualValue: max(1, target.value / 2),
            skipReason: .tooHard,
            completedAt: now
        ))
        persist()
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func refresh(now: Date = Date()) {
        var effects: [RestEffect] = []
        let next = RestTimerStateMachine.reduce(rest, .tick(now: now), &effects)
        if next != rest { rest = next }
        if effects.contains(.autoAdvanceToNextSet) {
            rest = .idle
            advance()
        }
    }

    func extendRest(by seconds: Int = 15, now: Date = Date()) {
        var effects: [RestEffect] = []
        rest = RestTimerStateMachine.reduce(rest, .extend(seconds: seconds, now: now), &effects)
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
    }

    func skipRest() {
        rest = .idle
        advance()
    }

    func endWorkout() {
        rest = .idle
        persist(finishedAt: Date())
        onFinish?()
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
        guard seconds > 0 else {
            advance()
            return
        }
        startRest(seconds: seconds, kicker: kicker, now: now)
    }

    private func startRest(seconds: Int, kicker: String, now: Date) {
        restKicker = kicker
        var effects: [RestEffect] = []
        rest = RestTimerStateMachine.reduce(rest, .start(seconds: seconds, now: now), &effects)
    }

    private func advance() {
        rest = .idle
        guard stepIndex + 1 < flow.steps.count else { return }
        stepIndex += 1
        autoStartRestIfBreak(now: Date())
    }

    private func autoStartRestIfBreak(now: Date) {
        switch currentStep {
        case let .roundBreak(seconds)?:
            startRest(seconds: seconds, kicker: "回合休息", now: now)
        case let .blockBreak(seconds, nextTitle)?:
            startRest(seconds: seconds, kicker: "下一项 · \(nextTitle)", now: now)
        case .finished?:
            onFinish?()
        default:
            break
        }
    }
}
