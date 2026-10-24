import Foundation
import Testing
@testable import DongKeCore

private let base = Date(timeIntervalSince1970: 1_761_000_000)

private func makeLog(
    session: UUID,
    item: String,
    set: Int,
    planned: Int,
    actual: Int? = nil,
    status: SetStatus = .done,
    skip: SkipReason? = nil,
    at: Date
) -> SetLog {
    SetLog(
        sessionId: session,
        prescriptionId: item,
        setIndex: set,
        status: status,
        plannedValue: planned,
        actualValue: actual ?? planned,
        skipReason: skip,
        completedAt: at
    )
}

private func cleared(_ session: UUID, item: String = "i1", sets: Int, planned: Int, offset: TimeInterval = 0) -> [SetLog] {
    (0..<sets).map { index in
        makeLog(
            session: session,
            item: item,
            set: index,
            planned: planned,
            actual: planned + 2,
            at: base.addingTimeInterval(offset + Double(index))
        )
    }
}

private func twoClearedSessions(item: String = "i1", sets: Int = 3, planned: Int) -> [SetLog] {
    let first = UUID()
    let second = UUID()
    return cleared(first, item: item, sets: sets, planned: planned)
        + cleared(second, item: item, sets: sets, planned: planned, offset: 86_400 * 3)
}

private func plan(
    items: [ExercisePrescription],
    source: PlanSource = .generated
) -> WorkoutPlan {
    var plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: items)])])
    plan.source = source
    return plan
}

private func item(
    id: String = "i1",
    name: String = "深蹲",
    sets: Int = 3,
    value: Int = 12,
    load: Double = 0,
    loadType: LoadType = .bodyweight,
    catalog: String = "squat"
) -> ExercisePrescription {
    ExercisePrescription(
        itemId: id,
        catalogId: catalog,
        name: name,
        sets: sets,
        target: SetTarget(type: .reps, value: value, perSide: false),
        restSec: 90,
        load: Load(type: loadType, value: load)
    )
}

private func fullWeek() -> WorkoutPlan {
    let days = (1...7).map { index in
        makeDay(
            index: index,
            blocks: [makeBlock(id: "b\(index)", items: [makeItem(id: "i\(index)", name: "动作\(index)", sets: 3)])]
        )
    }
    return makePlan(days: days)
}

@Test("次数没到顶先加次数")
func repsComeFirst() throws {
    let proposal = try #require(DoseAdjustment.propose(plan: plan(items: [item(value: 12)]), logs: twoClearedSessions(planned: 12)))
    #expect(proposal.changes.count == 1)
    #expect(proposal.changes[0].field == .reps)
    #expect(proposal.changes[0].toValue == 14)
}

@Test("次数到顶、有重量，就加重 2.5%")
func loadComesSecond() throws {
    let plan = plan(items: [item(value: 14, load: 20, loadType: .dumbbell)])
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: twoClearedSessions(planned: 14)))
    #expect(proposal.changes[0].field == .load)
    #expect(proposal.changes[0].toValue == 20.5)
}

@Test("次数到顶、没重量，就加一组")
func setsComeThird() throws {
    let plan = plan(items: [item(value: 14)])
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: twoClearedSessions(planned: 14)))
    #expect(proposal.changes[0].field == .sets)
    #expect(proposal.changes[0].toValue == 4)
}

@Test("同一个提案只动一种杠杆")
func oneLeverPerProposal() throws {
    let a = item(id: "i1", name: "深蹲", value: 12)
    let b = item(id: "i2", name: "卧推", value: 14, load: 20, loadType: .dumbbell, catalog: "benchpress")
    let logs = twoClearedSessions(item: "i1", planned: 12) + twoClearedSessions(item: "i2", planned: 14)
    let proposal = try #require(DoseAdjustment.propose(plan: plan(items: [a, b]), logs: logs))
    #expect(proposal.fields == [.reps])
    #expect(proposal.changes.map(\.itemId) == ["i1"])
}

@Test("连续两次「太累」就降强度，组数不动")
func tooHardLowersLoad() throws {
    let plan = plan(items: [item(value: 12, load: 20, loadType: .dumbbell)])
    var logs: [SetLog] = []
    for index in 0..<2 {
        let session = UUID()
        for setIndex in 0..<2 {
            logs.append(makeLog(
                session: session,
                item: "i1",
                set: setIndex,
                planned: 12,
                actual: 0,
                status: .skipped,
                skip: .tooHard,
                at: base.addingTimeInterval(Double(index) * 86_400 + Double(setIndex))
            ))
        }
    }
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: logs))
    #expect(proposal.kind == .dose)
    #expect(proposal.changes[0].field == .load)
    #expect(proposal.changes[0].toValue == 18)
}

@Test("只「太累」一次不动")
func tooHardNeedsTwo() {
    var logs: [SetLog] = []
    let session = UUID()
    for setIndex in 0..<2 {
        logs.append(makeLog(session: session, item: "i1", set: setIndex, planned: 12, actual: 0, status: .skipped, skip: .tooHard, at: base))
    }
    #expect(DoseAdjustment.propose(plan: plan(items: [item(value: 12)]), logs: logs) == nil)
}

@Test("连着三次没时间，砍掉最后那个动作")
func noTimeDropsLastExercise() throws {
    let items = (1...6).map { item(id: "i\($0)", name: "动作\($0)", value: 12) }
    let plan = plan(items: items)
    var logs: [SetLog] = []
    for index in 0..<3 {
        let session = UUID()
        for setIndex in 0..<3 {
            logs.append(makeLog(
                session: session,
                item: "i6",
                set: setIndex,
                planned: 12,
                actual: 0,
                status: .skipped,
                skip: .noTime,
                at: base.addingTimeInterval(Double(index) * 86_400 + Double(setIndex))
            ))
        }
    }
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: logs, now: base.addingTimeInterval(86_400 * 3)))
    #expect(proposal.droppedItemIds == ["i6"])
    #expect(proposal.changes.isEmpty)
}

@Test("动作数没超过五个，不砍")
func noTimeRespectsSmallSession() {
    let items = (1...5).map { item(id: "i\($0)", name: "动作\($0)", value: 12) }
    var logs: [SetLog] = []
    for index in 0..<3 {
        let session = UUID()
        logs.append(makeLog(
            session: session,
            item: "i5",
            set: 0,
            planned: 12,
            actual: 0,
            status: .skipped,
            skip: .noTime,
            at: base.addingTimeInterval(Double(index) * 86_400)
        ))
    }
    #expect(DoseAdjustment.propose(plan: plan(items: items), logs: logs, now: base.addingTimeInterval(86_400 * 3)) == nil)
}

@Test("没器械就换动作，不降量")
func noEquipmentSwaps() throws {
    let swapTarget = try #require(ExerciseLibrary.all.first { $0.alternativeId != nil })
    let plan = plan(items: [item(catalog: swapTarget.id)])
    let logs = [makeLog(session: UUID(), item: "i1", set: 0, planned: 12, actual: 0, status: .skipped, skip: .noEquipment, at: base)]
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: logs))
    #expect(proposal.kind == .swap)
    #expect(proposal.changes[0].field == .exercise)
    #expect(proposal.changes[0].toId != nil)
}

@Test("没有替代动作时，没器械只记录不提案")
func missingAlternativeStaysSilent() throws {
    let plain = try #require(ExerciseLibrary.all.first { $0.alternativeId == nil })
    let plan = plan(items: [item(catalog: plain.id)])
    let logs = [makeLog(session: UUID(), item: "i1", set: 0, planned: 12, actual: 0, status: .skipped, skip: .noEquipment, at: base)]
    #expect(DoseAdjustment.propose(plan: plan, logs: logs) == nil)
}

@Test("疼一次就出手")
func painOnceIsEnough() throws {
    let plan = plan(items: [item(value: 12)])
    let logs = [makeLog(session: UUID(), item: "i1", set: 0, planned: 12, actual: 0, status: .skipped, skip: .pain, at: base)]
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: logs, now: base.addingTimeInterval(86_400)))
    #expect(proposal.kind == .safety)
    #expect(proposal.changes[0].toValue == 10)
}

@Test("疼和该加量同时出现，只出保护")
func painBeatsDose() throws {
    let plan = plan(items: [item(value: 12)])
    let painLogs = [makeLog(session: UUID(), item: "i1", set: 0, planned: 12, actual: 0, status: .skipped, skip: .pain, at: base.addingTimeInterval(86_400 * 5))]
    let cleared = twoClearedSessions(planned: 12)
    let proposal = try #require(DoseAdjustment.propose(plan: plan, logs: cleared + painLogs, now: base.addingTimeInterval(86_400 * 6)))
    #expect(proposal.kind == .safety)
    #expect(proposal.changes.allSatisfy { $0.toValue < $0.fromValue })
}

@Test("拒绝过的同一条不再提")
func rejectedProposalIsQuiet() {
    let plan = plan(items: [item(value: 12)])
    let logs = twoClearedSessions(planned: 12)
    let first = DoseAdjustment.propose(plan: plan, logs: logs)!
    let memory = ProposalMemory().rejecting(first, now: base)
    let context = DoseContext(plan: plan, logs: logs, memory: memory, now: base)
    #expect(DoseAdjustment.propose(context) == nil)
}

@Test("连拒三次整体安静，且不解释")
func threeRejectionsSilenceEverything() {
    let plan = plan(items: [item(value: 12)])
    let memory = ProposalMemory(consecutiveRejections: 3)
    let context = DoseContext(plan: plan, logs: twoClearedSessions(planned: 12), memory: memory, now: base)
    #expect(DoseAdjustment.propose(context) == nil)
}

@Test("采纳一次就把拒绝计数清零")
func acceptingResetsRejections() {
    let plan = plan(items: [item(value: 12)])
    let proposal = DoseAdjustment.propose(plan: plan, logs: twoClearedSessions(planned: 12))!
    let memory = ProposalMemory(consecutiveRejections: 2).accepting(proposal, now: base)
    #expect(memory.consecutiveRejections == 0)
    #expect(memory.doseStreak == 1)
}

@Test("外来计划不主动提")
func foreignPlanStaysSilent() {
    let plan = plan(items: [item(value: 12)], source: .ai)
    #expect(DoseAdjustment.propose(plan: plan, logs: twoClearedSessions(planned: 12)) == nil)
}

@Test("问了才给建议，外来计划也一样")
func askedForeignPlanAnswers() throws {
    let plan = plan(items: [item(value: 12)], source: .ai)
    let context = DoseContext(plan: plan, logs: twoClearedSessions(planned: 12), asked: true, now: base)
    #expect(try #require(DoseAdjustment.propose(context)).changes.isEmpty == false)
}

@Test("连续两个计划日没开始，先给半节课")
func rebuildAfterTwoMissedDays() throws {
    let now = base.addingTimeInterval(86_400 * 30)
    let context = DoseContext(plan: fullWeek(), logs: [], now: now)
    let proposal = try #require(DoseAdjustment.propose(context))
    #expect(proposal.kind == .rebuild)
    #expect(proposal.droppedItemIds.count == 3)
    #expect(proposal.changes.isEmpty == false)
}

@Test("昨天练过就不重建")
func rebuildNeedsTwoMissedDays() {
    let now = base.addingTimeInterval(86_400 * 30)
    let logs = [makeLog(session: UUID(), item: "i1", set: 0, planned: 12, actual: 12, at: now.addingTimeInterval(-86_400))]
    #expect(DoseAdjustment.propose(DoseContext(plan: fullWeek(), logs: logs, now: now)) == nil)
}

@Test("重建不动版本号，加量才动")
func rebuildKeepsRevision() throws {
    let now = base.addingTimeInterval(86_400 * 30)
    let original = fullWeek()
    let proposal = try #require(DoseAdjustment.propose(DoseContext(plan: original, logs: [], now: now)))
    let next = DoseAdjustment.apply(proposal, to: original, now: now)
    #expect(next.revision == original.revision)
    #expect(next.days.flatMap(\.blocks).flatMap(\.items).count < original.days.flatMap(\.blocks).flatMap(\.items).count)
}

@Test("连着加了三次，第四次改成缓一缓")
func deloadAfterThreeIncreases() throws {
    let plan = plan(items: [item(value: 12)])
    let memory = ProposalMemory(doseStreak: 3)
    let context = DoseContext(plan: plan, logs: [], memory: memory, now: base)
    let proposal = try #require(DoseAdjustment.propose(context))
    #expect(proposal.isReduction)
    #expect(proposal.changes[0].toValue == 7)
}

@Test("只加过两次还继续加")
func twoIncreasesStillClimb() throws {
    let plan = plan(items: [item(value: 12)])
    let memory = ProposalMemory(doseStreak: 2)
    let context = DoseContext(plan: plan, logs: twoClearedSessions(planned: 12), memory: memory, now: base)
    let proposal = try #require(DoseAdjustment.propose(context))
    #expect(proposal.isReduction == false)
    #expect(proposal.changes[0].toValue == 14)
}

@Test("降量被采纳会把连续加量清零，并且记下降量时间")
func deloadResetsStreak() {
    let plan = plan(items: [item(value: 12)])
    let memory = ProposalMemory(doseStreak: 3)
    let proposal = DoseAdjustment.propose(DoseContext(plan: plan, logs: [], memory: memory, now: base))!
    let next = memory.accepting(proposal, now: base)
    #expect(next.doseStreak == 0)
    #expect(next.lastDeloadAt == base)
}

private func loadPlan() -> WorkoutPlan {
    plan(items: [item(value: 14, load: 20, loadType: .dumbbell, catalog: "goblet_squat")])
}

@Test("连着两次都在第一次训练就崩，幅度减半")
func toleranceShrinksAmplitude() throws {
    let memory = ProposalMemory(recentSetbacks: [1, 1])
    let context = DoseContext(plan: loadPlan(), logs: twoClearedSessions(planned: 14), memory: memory, now: base)
    let proposal = try #require(DoseAdjustment.propose(context))
    #expect(proposal.changes[0].field == .load)
    #expect(proposal.changes[0].toValue == 20.3)
}

@Test("连着两次都撑过第三次，幅度用上限")
func toleranceRaisesAmplitude() throws {
    let memory = ProposalMemory(recentSetbacks: [4, 3])
    let context = DoseContext(plan: loadPlan(), logs: twoClearedSessions(planned: 14), memory: memory, now: base)
    let proposal = try #require(DoseAdjustment.propose(context))
    #expect(proposal.changes[0].toValue == 21)
}

@Test("一次早崩一次撑住，就用默认幅度")
func toleranceStaysDefault() throws {
    let memory = ProposalMemory(recentSetbacks: [2, 1])
    let context = DoseContext(plan: loadPlan(), logs: twoClearedSessions(planned: 14), memory: memory, now: base)
    let proposal = try #require(DoseAdjustment.propose(context))
    #expect(proposal.changes[0].toValue == 20.5)
}

@Test("只崩过一次，还看不出耐受，用默认幅度")
func toleranceNeedsTwoSamples() {
    #expect(ProposalMemory(recentSetbacks: [1]).loadAmplitude == ProposalMemory.defaultAmplitude)
}

@Test("加量之后的第二次训练就崩，记成第二次")
func settlingRecordsSetbackIndex() {
    let first = UUID()
    let second = UUID()
    let logs = [
        makeLog(session: first, item: "i1", set: 0, planned: 14, actual: 14, at: base.addingTimeInterval(86_400)),
        makeLog(session: second, item: "i1", set: 0, planned: 14, actual: 7, status: .downgraded, at: base.addingTimeInterval(86_400 * 2))
    ]
    let memory = ProposalMemory(pendingSetbackSince: base, pendingItemIds: ["i1"]).settling(logs: logs, now: base.addingTimeInterval(86_400 * 2))
    #expect(memory.recentSetbacks == [2])
    #expect(memory.pendingSetbackSince == nil)
}

@Test("重建完成后回到停练前的八成，而不是满量")
func restoresToEightyPercent() throws {
    let original = plan(items: [item(value: 12)])
    let halved = plan(items: [item(value: 6)])
    let proposal = try #require(DoseAdjustment.restoreProposal(from: original, current: halved, now: base))
    #expect(proposal.kind == .dose)
    #expect(proposal.changes[0].toValue == 10)
    #expect(proposal.isReduction == false)
}

@Test("已经回到八成就不再提恢复")
func restoreStopsAtEightyPercent() {
    let original = plan(items: [item(value: 12)])
    let current = plan(items: [item(value: 10)])
    #expect(DoseAdjustment.restoreProposal(from: original, current: current, now: base) == nil)
}
