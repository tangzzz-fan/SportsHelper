import Foundation
import Testing

@testable import DongKeCore

struct SwapProposalTests {
    private func plan(catalogId: String = "dumbbell_row") -> WorkoutPlan {
        let item = ExercisePrescription(
            itemId: "i1",
            catalogId: catalogId,
            name: "哑铃划船",
            sets: 4,
            target: SetTarget(type: .reps, value: 12, perSide: false),
            restSec: 90,
            load: Load(type: .dumbbell, value: 8)
        )
        return WorkoutPlan(
            meta: PlanMeta(
                title: "全身",
                goal: .buildMuscle,
                level: .beginner,
                daysPerWeek: 3,
                sessionMinutes: 30
            ),
            days: [
                PlanDay(
                    dayIndex: 1,
                    weekday: .monday,
                    isRestDay: false,
                    title: "上肢",
                    scheduledTime: nil,
                    estimatedMinutes: 30,
                    blocks: [
                        ExerciseBlock(
                            blockId: "b1",
                            kind: .main,
                            title: "主训练",
                            rounds: 1,
                            restBetweenItemsSec: 0,
                            restBetweenRoundsSec: 0,
                            items: [item]
                        )
                    ]
                )
            ]
        )
    }

    private func swappedLog(sessionId: UUID, at date: Date, newId: String = "squat") -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "i1",
            catalogId: newId,
            targetType: .reps,
            setIndex: 1,
            status: .done,
            plannedValue: 12,
            actualValue: 12,
            swappedFromCatalogId: "dumbbell_row",
            completedAt: date
        )
    }

    @Test func twoSessionsOfSwappingBecomesSwapProposal() {
        let now = Date()
        let logs = [
            swappedLog(sessionId: UUID(), at: now.addingTimeInterval(-3 * 86_400)),
            swappedLog(sessionId: UUID(), at: now.addingTimeInterval(-86_400))
        ]
        let context = DoseContext(plan: plan(), logs: logs, now: now)
        let proposal = DoseAdjustment.repeatedSwapProposal(
            context,
            sessions: DoseAdjustment.loggedSessions(logs)
        )
        #expect(proposal?.kind == .swap)
        #expect(proposal?.changes.first?.field == .exercise)
        #expect(proposal?.changes.first?.toId == "squat")
    }

    @Test func singleSwapDoesNotChangeThePlan() {
        let now = Date()
        let logs = [swappedLog(sessionId: UUID(), at: now.addingTimeInterval(-86_400))]
        let context = DoseContext(plan: plan(), logs: logs, now: now)
        #expect(DoseAdjustment.repeatedSwapProposal(context, sessions: DoseAdjustment.loggedSessions(logs)) == nil)
    }

    @Test func noSwapLogsGiveNoProposal() {
        let now = Date()
        let plain = SetLog(
            sessionId: UUID(),
            prescriptionId: "i1",
            catalogId: "dumbbell_row",
            targetType: .reps,
            setIndex: 1,
            status: .done,
            plannedValue: 12,
            actualValue: 12,
            completedAt: now
        )
        let context = DoseContext(plan: plan(), logs: [plain], now: now)
        #expect(DoseAdjustment.repeatedSwapProposal(context, sessions: DoseAdjustment.loggedSessions([plain])) == nil)
    }

    @Test func doseCountsTheOriginalMuscle() {
        let log = swappedLog(sessionId: UUID(), at: Date(), newId: "squat")
        #expect(DoseReportBuilder.muscles(for: log) == PrimaryMuscleMap.muscles(for: "dumbbell_row"))
        #expect(DoseReportBuilder.muscles(for: log) != PrimaryMuscleMap.muscles(for: "squat"))
    }
}
