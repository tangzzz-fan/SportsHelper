import Foundation
import Testing

@testable import DongKeCore

struct LoadRackProgressionTests {
    private let day = Date(timeIntervalSince1970: 1_760_000_000)

    private func item(value: Int = 15, sets: Int = 3, load: Double = 8) -> ExercisePrescription {
        ExercisePrescription(
            itemId: "i1",
            catalogId: "dumbbell_row",
            name: "哑铃划船",
            sets: sets,
            target: SetTarget(type: .reps, value: value, perSide: false),
            restSec: 90,
            load: Load(type: .dumbbell, value: load)
        )
    }

    private func plan(_ item: ExercisePrescription) -> WorkoutPlan {
        makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [item])])])
    }

    private func session(
        sets: Int,
        planned: Int,
        actual: Int? = nil,
        load: Double?,
        daysLater: Double
    ) -> [SetLog] {
        let id = UUID()
        let at = day.addingTimeInterval(daysLater * 86_400)
        return (1...sets).map { index in
            SetLog(
                sessionId: id,
                prescriptionId: "i1",
                catalogId: "dumbbell_row",
                targetType: .reps,
                setIndex: index,
                status: .done,
                plannedValue: planned,
                actualValue: actual ?? planned,
                actualLoad: load.map { Load(type: .dumbbell, value: $0) },
                completedAt: at.addingTimeInterval(Double(index))
            )
        }
    }

    private func propose(_ item: ExercisePrescription, logs: [SetLog], rack: LoadRack) -> PlanProposal? {
        DoseAdjustment.propose(DoseContext(
            plan: plan(item),
            logs: logs,
            now: day.addingTimeInterval(10 * 86_400),
            rack: rack
        ))
    }

    @Test func loadStepFollowsTheRackInsteadOfAMultiplier() throws {
        let logs = session(sets: 3, planned: 15, actual: 16, load: nil, daysLater: 0)
            + session(sets: 3, planned: 15, actual: 16, load: nil, daysLater: 3)
        let proposal = try #require(propose(item(value: 15, load: 8), logs: logs, rack: .step25))
        #expect(proposal.changes.first?.field == .load)
        #expect(proposal.changes.first?.toValue == 10)
    }

    @Test func fiveKiloRackJumpsToFifteen() throws {
        let logs = session(sets: 3, planned: 15, actual: 16, load: nil, daysLater: 0)
            + session(sets: 3, planned: 15, actual: 16, load: nil, daysLater: 3)
        let proposal = try #require(propose(item(value: 15, load: 10), logs: logs, rack: .step5))
        #expect(proposal.changes.first?.toValue == 15)
    }

    @Test func noHeavierPlateFallsBackToAnExtraSet() throws {
        let rack = LoadRack(kind: .fixed, plates: [4, 6, 8])
        let logs = session(sets: 3, planned: 15, actual: 16, load: nil, daysLater: 0)
            + session(sets: 3, planned: 15, actual: 16, load: nil, daysLater: 3)
        let proposal = try #require(propose(item(value: 15, sets: 3, load: 8), logs: logs, rack: rack))
        #expect(proposal.changes.first?.field == .sets)
        #expect(proposal.changes.first?.toValue == 4)
    }

    @Test func twoSessionsAtAHeavierWeightRewriteThePrescription() throws {
        let logs = session(sets: 3, planned: 12, actual: 12, load: 10, daysLater: 0)
            + session(sets: 3, planned: 12, actual: 12, load: 10, daysLater: 3)
        let proposal = try #require(propose(item(value: 12, load: 8), logs: logs, rack: .step25))
        #expect(proposal.changes.first?.field == .load)
        #expect(proposal.changes.first?.fromValue == 8)
        #expect(proposal.changes.first?.toValue == 10)
    }

    @Test func oneHeavierSessionIsNotEnough() {
        let logs = session(sets: 3, planned: 12, actual: 12, load: 10, daysLater: 0)
        #expect(propose(item(value: 12, load: 8), logs: logs, rack: .step25) == nil)
    }

    @Test func stayingAtThePrescribedWeightChangesNothing() {
        let logs = session(sets: 3, planned: 12, actual: 12, load: 8, daysLater: 0)
            + session(sets: 3, planned: 12, actual: 12, load: 8, daysLater: 3)
        #expect(propose(item(value: 12, load: 8), logs: logs, rack: .step25) == nil)
    }

    @Test func heavierButFewerRepsIsNotTreatedAsFailure() throws {
        // 用户自己加到 10kg，次数从 12 掉到 9：不触发「太累」，也不判成没完成。
        let logs = session(sets: 3, planned: 12, actual: 9, load: 10, daysLater: 0)
            + session(sets: 3, planned: 12, actual: 9, load: 10, daysLater: 3)
        let proposal = try #require(propose(item(value: 12, load: 8), logs: logs, rack: .step25))
        #expect(proposal.kind == .dose)
        #expect(proposal.changes.first?.field == .load)
        #expect(proposal.reason.contains("太累") == false)
    }
}
