import Foundation
import Testing
@testable import DongKeCore

private let reserveDay = Date(timeIntervalSince1970: 1_760_000_000)

private func reservePlan(value: Int = 12, sets: Int = 3, load: Load = Load(type: .bodyweight, value: 0)) -> WorkoutPlan {
    var item = makeItem(sets: sets, value: value)
    item.load = load
    return makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [item])])])
}

private func log(
    session: UUID,
    setIndex: Int,
    planned: Int = 12,
    actual: Int? = nil,
    status: SetStatus = .done,
    rpe: Int? = nil,
    offsetDays: Int = 0
) -> SetLog {
    SetLog(
        sessionId: session,
        prescriptionId: "i1",
        setIndex: setIndex,
        status: status,
        plannedValue: planned,
        actualValue: actual ?? planned,
        rpe: rpe,
        completedAt: reserveDay.addingTimeInterval(Double(offsetDays) * 86_400 + Double(setIndex))
    )
}

private func session(
    sets: Int = 3,
    lastRpe: Int?,
    middleRpe: Int? = nil,
    extra: Int = 0,
    extraOnAll: Int = 0,
    planned: Int = 12,
    lastStatus: SetStatus = .done,
    offsetDays: Int = 0
) -> [SetLog] {
    let id = UUID()
    return (0..<sets).map { index in
        let isLast = index == sets - 1
        return log(
            session: id,
            setIndex: index,
            planned: planned,
            actual: planned + extraOnAll + (isLast ? extra : 0),
            status: isLast ? lastStatus : .done,
            rpe: isLast ? lastRpe : middleRpe,
            offsetDays: offsetDays + index
        )
    }
}

private func twoBy(_ build: (UUID, Int) -> [SetLog]) -> [SetLog] {
    build(UUID(), 0) + build(UUID(), 3)
}

@Suite("余力提案")
struct ReserveProposalTests {

    @Test("连续两次最后都说还能做三次以上，加两个次数")
    func addsRepsOnReserve() throws {
        let logs = twoBy { _, offset in session(lastRpe: 2, offsetDays: offset) }
        let proposal = try #require(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay))
        #expect(proposal.kind == .dose)
        #expect(proposal.changes.count == 1)
        #expect(proposal.changes[0].field == .reps)
        #expect(proposal.changes[0].toValue == 14)
        #expect(proposal.reason.contains("最后一组"))
        #expect(proposal.reason.contains("负重先不动"))
    }

    @Test("很轻松（还剩一大截力气）也算余力")
    func countsVeryEasy() {
        let logs = twoBy { _, offset in session(lastRpe: 1, offsetDays: offset) }
        #expect(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay) != nil)
    }

    @Test("还能做两次不算——阈值是三次以上")
    func threeOrMoreOnly() {
        let logs = twoBy { _, offset in session(lastRpe: 3, offsetDays: offset) }
        #expect(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay) == nil)
    }

    @Test("只说过一次不算")
    func oneSessionIsNotEnough() {
        let logs = session(lastRpe: 2)
        #expect(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay) == nil)
    }

    @Test("最后一组没选，就没有证据")
    func noRatingNoProposal() {
        let logs = twoBy { _, offset in session(lastRpe: nil, middleRpe: 2, offsetDays: offset) }
        #expect(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay) == nil)
    }

    @Test("余力记在中间组不算——只看每个动作的最后一组")
    func middleSetRatingIsIgnored() {
        let logs = twoBy { _, offset in session(lastRpe: nil, middleRpe: 1, offsetDays: offset) }
        #expect(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay) == nil)
    }

    @Test("最后一组是跳过，不算余力")
    func skippedLastSetIsNotEvidence() {
        let logs = twoBy { _, offset in
            session(lastRpe: 2, lastStatus: .skipped, offsetDays: offset)
        }
        #expect(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay) == nil)
    }

    @Test("目标改过以后，旧记录不再算证据")
    func staleTargetIsNotEvidence() {
        let logs = twoBy { _, offset in
            session(lastRpe: 2, planned: 10, offsetDays: offset)
        }
        #expect(DoseAdjustment.propose(plan: reservePlan(value: 12), logs: logs, now: reserveDay) == nil)
    }

    @Test("次数到顶时，余力不加重也不加组——沉默")
    func atCeilingStaysSilent() {
        let logs = twoBy { _, offset in
            session(lastRpe: 2, planned: 15, offsetDays: offset)
        }
        let plan = reservePlan(value: 15, load: Load(type: .dumbbell, value: 10))
        #expect(DoseAdjustment.propose(plan: plan, logs: logs, now: reserveDay) == nil)
    }

    @Test("静态动作（按秒）不走余力加次数")
    func durationTargetsAreSilent() {
        let plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
            makeItem(sets: 3, value: 10, targetType: .durationSec)
        ])])])
        let logs = twoBy { _, offset in
            session(lastRpe: 2, planned: 10, offsetDays: offset)
        }
        #expect(DoseAdjustment.propose(plan: plan, logs: logs, now: reserveDay) == nil)
    }

    @Test("真的多做了优先于只是觉得轻松——一次只讲一种证据")
    func extraRepsWinsOverReserve() throws {
        let logs = twoBy { _, offset in
            session(lastRpe: 2, extraOnAll: 2, offsetDays: offset)
        }
        let proposal = try #require(DoseAdjustment.propose(plan: reservePlan(), logs: logs, now: reserveDay))
        #expect(proposal.reason.contains("每组都多做了至少 1 个"))
        #expect(proposal.reason.contains("最后一组") == false)
    }
}

@Suite("每个动作的最后一组")
struct LastSetOfItemTests {

    private func flow() -> WorkoutFlowModel {
        let plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
            makeItem(id: "i1", sets: 2),
            makeItem(id: "i2", sets: 2)
        ])])])
        return WorkoutFlowModel(plan: plan, dayIndex: 1)
    }

    @Test("第一个动作的第一组不是最后一组")
    func firstSetIsNotLast() {
        #expect(flow().isLastSet(of: "i1", at: 0) == false)
    }

    @Test("第一个动作的第二组是它的最后一组，但不是全天的")
    func secondSetIsLastOfItem() {
        let model = flow()
        #expect(model.isLastSet(of: "i1", at: 1))
        #expect(model.steps.dropFirst(2).contains { step in
            if case .set = step { return true }
            return false
        })
    }

    @Test("最后一个动作的最后一组同时也是全天的最后一组")
    func veryLastSet() {
        let model = flow()
        #expect(model.isLastSet(of: "i2", at: 3))
        #expect(model.isLastSet(of: "i2", at: 2) == false)
    }
}
