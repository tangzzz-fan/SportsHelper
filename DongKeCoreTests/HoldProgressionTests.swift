import Foundation
import Testing
@testable import DongKeCore

private let holdDay = Date(timeIntervalSince1970: 1_765_000_000)

private func holdLog(
    session: UUID,
    item: String,
    setIndex: Int,
    planned: Int,
    status: SetStatus = .done,
    rpe: Int? = nil,
    skip: SkipReason? = nil,
    offsetDays: Int
) -> SetLog {
    SetLog(
        sessionId: session,
        prescriptionId: item,
        setIndex: setIndex,
        status: status,
        plannedValue: planned,
        actualValue: status == .skipped ? 0 : planned,
        skipReason: skip,
        rpe: rpe,
        completedAt: holdDay.addingTimeInterval(Double(offsetDays) * 86_400 + Double(setIndex))
    )
}

private func holdPlan(value: Int = 30, sets: Int = 3) -> WorkoutPlan {
    makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
        makeItem(sets: sets, value: value, targetType: .durationSec)
    ])])])
}

private func holdSessions(value: Int = 30, sets: Int = 3, rpe: Int? = 2) -> [SetLog] {
    let ids = [UUID(), UUID()]
    return ids.enumerated().flatMap { offset, id in
        (0..<sets).map { index in
            holdLog(
                session: id,
                item: "i1",
                setIndex: index,
                planned: value,
                rpe: index == sets - 1 ? rpe : nil,
                offsetDays: offset * 3 + index
            )
        }
    }
}

@Suite("保持时间进阶")
struct HoldProgressionTests {

    @Test("静态动作的余力加 5 秒保持时间")
    func reserveRaisesHold() throws {
        let proposal = try #require(DoseAdjustment.propose(plan: holdPlan(), logs: holdSessions(), now: holdDay))
        #expect(proposal.fields == [.hold])
        #expect(proposal.changes[0].toValue == 35)
        #expect(proposal.changes[0].summary == "深蹲 30 秒 → 35 秒")
    }

    @Test("保持时间到 60 秒后没有下一档")
    func holdCeilingHasNoNextStep() {
        let item = makeItem(value: 60, targetType: .durationSec)
        #expect(DoseAdjustment.lever(for: item) == nil)
        #expect(ProgressionAxis(item.target)?.raised(60) == nil)
    }

    @Test("45 秒加 5 秒到 50 秒，不被次数上限挡住")
    func holdIgnoresRepCeiling() throws {
        let proposal = try #require(DoseAdjustment.propose(
            plan: holdPlan(value: 45),
            logs: holdSessions(value: 45),
            now: holdDay
        ))
        #expect(proposal.changes[0].toValue == 50)
    }

    @Test("55 秒加 5 秒正好到 60 秒")
    func holdReachesCeiling() throws {
        let proposal = try #require(DoseAdjustment.propose(
            plan: holdPlan(value: 55),
            logs: holdSessions(value: 55),
            now: holdDay
        ))
        #expect(proposal.changes[0].toValue == 60)
    }

    @Test("疼一次：静态动作先减保持时间，不减组")
    func painEasesHold() throws {
        let plan = holdPlan(value: 30, sets: 3)
        let logs = [holdLog(
            session: UUID(), item: "i1", setIndex: 0, planned: 30,
            status: .skipped, skip: .pain, offsetDays: 1
        )]
        let proposal = try #require(DoseAdjustment.propose(
            plan: plan,
            logs: logs,
            now: holdDay.addingTimeInterval(86_400 * 2)
        ))
        #expect(proposal.kind == .safety)
        #expect(proposal.changes[0].field == .hold)
        #expect(proposal.changes[0].toValue == 20)
    }

    @Test("疼到 5 秒地板时回落到减组，不沉默")
    func painAtHoldFloorFallsBackToSets() throws {
        let plan = holdPlan(value: 5, sets: 3)
        let logs = [holdLog(
            session: UUID(), item: "i1", setIndex: 0, planned: 5,
            status: .skipped, skip: .pain, offsetDays: 1
        )]
        let proposal = try #require(DoseAdjustment.propose(
            plan: plan,
            logs: logs,
            now: holdDay.addingTimeInterval(86_400 * 2)
        ))
        #expect(proposal.kind == .safety)
        #expect(proposal.changes[0].field == .sets)
        #expect(proposal.changes[0].toValue == 2)
    }

    @Test("太累两次：静态动作减一档保持时间")
    func tooHardEasesHold() throws {
        let plan = holdPlan(value: 30, sets: 3)
        let ids = [UUID(), UUID()]
        let logs = ids.enumerated().flatMap { offset, id in
            (0..<3).map { index in
                holdLog(
                    session: id, item: "i1", setIndex: index, planned: 30,
                    status: index == 0 ? .skipped : .done,
                    skip: index == 0 ? .tooHard : nil,
                    offsetDays: offset * 3 + index
                )
            }
        }
        let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: logs, now: holdDay))
        #expect(proposal.changes[0].field == .hold)
        #expect(proposal.changes[0].toValue == 25)
    }

    @Test("太累到 5 秒地板时沉默，不转成减组")
    func tooHardAtHoldFloorStaysSilent() {
        let plan = holdPlan(value: 5, sets: 3)
        let ids = [UUID(), UUID()]
        let logs = ids.enumerated().flatMap { offset, id in
            (0..<3).map { index in
                holdLog(
                    session: id, item: "i1", setIndex: index, planned: 5,
                    status: index == 0 ? .skipped : .done,
                    skip: index == 0 ? .tooHard : nil,
                    offsetDays: offset * 3 + index
                )
            }
        }
        #expect(DoseAdjustment.propose(plan: plan, logs: logs, now: holdDay) == nil)
    }

    @Test("距离动作的疼仍按原口径减组")
    func distancePainStillReducesSets() throws {
        let plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
            makeItem(sets: 3, value: 1000, targetType: .distanceM)
        ])])])
        let logs = [holdLog(
            session: UUID(), item: "i1", setIndex: 0, planned: 1000,
            status: .skipped, skip: .pain, offsetDays: 1
        )]
        let proposal = try #require(DoseAdjustment.propose(
            plan: plan,
            logs: logs,
            now: holdDay.addingTimeInterval(86_400 * 2)
        ))
        #expect(proposal.changes[0].field == .sets)
        #expect(proposal.changes[0].toValue == 2)
    }

    @Test("连着加三次后，静态动作也降到六成")
    func deloadStaticHold() throws {
        let plan = holdPlan(value: 60)
        let memory = ProposalMemory(doseStreak: 3)
        let context = DoseContext(plan: plan, logs: [], memory: memory, now: holdDay)
        let proposal = try #require(DoseAdjustment.propose(context))
        #expect(proposal.isReduction)
        #expect(proposal.changes[0].field == .hold)
        #expect(proposal.changes[0].toValue == 35)
    }

    @Test("停练后静态动作也回到八成")
    func restoreStaticHold() throws {
        let original = holdPlan(value: 60)
        var current = original
        current.days[0].blocks[0].items[0].target.value = 35
        let proposal = try #require(DoseAdjustment.restoreProposal(
            from: original,
            current: current,
            now: holdDay
        ))
        #expect(proposal.changes[0].field == .hold)
        #expect(proposal.changes[0].toValue == 45)
    }

    @Test("距离动作不参与余力进阶")
    func distanceHasNoAxis() {
        let item = makeItem(value: 1000, targetType: .distanceM)
        #expect(ProgressionAxis(item.target) == nil)
        #expect(DoseAdjustment.lever(for: item) == nil)
    }

    @Test("一次提案只出一种字段：次数优先级高于保持时间")
    func mixedPlanPicksOneAxis() throws {
        let plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
            makeItem(id: "i1", sets: 3, value: 12, targetType: .reps),
            makeItem(id: "i2", sets: 3, value: 10, targetType: .durationSec)
        ])])])
        let dynamic = holdSessions(value: 12)
            .map { log -> SetLog in
                var copy = log
                copy.prescriptionId = "i1"
                return copy
            }
        let holds = holdSessions(value: 10)
            .map { log -> SetLog in
                var copy = log
                copy.prescriptionId = "i2"
                return copy
            }
        let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: dynamic + holds, now: holdDay))
        #expect(proposal.fields == [.reps])
        #expect(proposal.changes.map(\.itemId) == ["i1"])
    }

    @Test("只有静态动作有余力时，提案走保持时间")
    func onlyHoldEvidencePicksHold() throws {
        let plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
            makeItem(id: "i1", sets: 3, value: 12, targetType: .reps),
            makeItem(id: "i2", sets: 3, value: 10, targetType: .durationSec)
        ])])])
        let dynamic = holdSessions(value: 12, rpe: nil)
            .map { log -> SetLog in
                var copy = log
                copy.prescriptionId = "i1"
                return copy
            }
        let holds = holdSessions(value: 10)
            .map { log -> SetLog in
                var copy = log
                copy.prescriptionId = "i2"
                return copy
            }
        let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: dynamic + holds, now: holdDay))
        #expect(proposal.fields == [.hold])
        #expect(proposal.changes.map(\.itemId) == ["i2"])
    }

    @Test("采纳保持时间提案后只改秒数，组数不动")
    func applyChangesOnlyHold() {
        let plan = holdPlan(value: 30, sets: 3)
        let proposal = PlanProposal(
            kind: .dose,
            changes: [PlanProposal.Change(
                itemId: "i1", name: "深蹲", field: .hold, fromValue: 30, toValue: 35
            )],
            reason: "test",
            createdAt: holdDay
        )
        let next = DoseAdjustment.apply(proposal, to: plan, now: holdDay)
        let item = next.days[0].blocks[0].items[0]
        #expect(item.target.value == 35)
        #expect(item.sets == 3)
        #expect(next.revision == plan.revision + 1)
    }
}
