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

    var stepIndex = 0
    var logs: [SetLog] = []
    var rest: RestState = .idle
    var restKicker = "组间休息"
    var finishedAt: Date?
    var restFinishedToken = 0

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

}
