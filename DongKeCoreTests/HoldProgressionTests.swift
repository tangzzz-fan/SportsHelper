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
    offsetDays: Int
) -> SetLog {
    SetLog(
        sessionId: session,
        prescriptionId: item,
        setIndex: setIndex,
        status: status,
        plannedValue: planned,
        actualValue: planned,
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
