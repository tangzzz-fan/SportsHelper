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
    let flow: WorkoutFlowModel
    var script: [FlowStep]
    let startedAt: Date
    var store: SessionStore?
    var setLogStore: SetLogStore?
    var checkpointStore: WorkoutCheckpointStore?
    weak var restNotifications: (any RestNotificationScheduling)?

    var stepIndex = 0
    var logs: [SetLog] = []
    var rest: RestState = .idle
    var restKicker = "组间休息"
    var finishedAt: Date?
    var restFinishedToken = 0
    var voice: WorkoutVoiceSession?
    var setTimer = SetTimerDriver()

    init(
        plan: WorkoutPlan,
        dayIndex: Int,
        planDate: Date? = nil,
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
