import Foundation
import Testing
@testable import DongKeCore

private func makeLog(
    session: UUID,
    item: String = "i1",
    setIndex: Int,
    planned: Int = 12,
    actual: Int? = nil,
    status: SetStatus = .done,
    rpe: Int? = nil,
    at: Date
) -> SetLog {
    SetLog(
        sessionId: session,
        prescriptionId: item,
        setIndex: setIndex,
        status: status,
        plannedValue: planned,
        actualValue: actual ?? planned,
        rpe: rpe,
        completedAt: at
    )
}

private let day = Date(timeIntervalSince1970: 1_760_000_000)

private func plan(value: Int = 12, sets: Int = 3, type: SetTargetType = .reps) -> WorkoutPlan {
    makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [makeItem(sets: sets, value: value, targetType: type)])])])
}

private func allCleared(_ session: UUID, sets: Int = 3, planned: Int = 12, extra: Int = 2) -> [SetLog] {
    (0..<sets).map { index in
        makeLog(
            session: session,
            setIndex: index,
            planned: planned,
            actual: planned + extra,
            at: day.addingTimeInterval(Double(index))
        )
    }
}

private func twoSessions(extra: Int = 2, sets: Int = 3, planned: Int = 12) -> [SetLog] {
    let first = UUID()
    let second = UUID()
    return allCleared(first, sets: sets, planned: planned, extra: extra)
        + allCleared(second, sets: sets, planned: planned, extra: extra).map { log in
            var copy = log
            copy.completedAt = log.completedAt.addingTimeInterval(86_400 * 3)
            return copy
        }
}

@Test("连续两次全组都多做，提一次加次数")
func proposesAfterTwoClearedSessions() throws {
    let proposal = try #require(DoseAdjustment.propose(plan: plan(), logs: twoSessions(), now: day))
    #expect(proposal.kind == .dose)
    #expect(proposal.changes.count == 1)
    #expect(proposal.changes[0].field == .reps)
    #expect(proposal.changes[0].fromValue == 12)
    #expect(proposal.changes[0].toValue == 14)
}

@Test("只做过一次，不说话")
func staysSilentWithOneSession() {
    let logs = allCleared(UUID())
    #expect(DoseAdjustment.propose(plan: plan(), logs: logs, now: day) == nil)
}

@Test("两次里有一次没多做，不说话")
func staysSilentWhenOneSessionIsFlat() {
    var logs = twoSessions()
    let secondSession = logs[logs.count - 1].sessionId
    logs = logs.map { log in
        guard log.sessionId == secondSession, log.setIndex == 0 else { return log }
        var copy = log
        copy.actualValue = copy.plannedValue
        return copy
    }
    #expect(DoseAdjustment.propose(plan: plan(), logs: logs, now: day) == nil)
}

@Test("少记一组不算「全组」")
func partialSessionDoesNotCount() {
    let logs = twoSessions().filter { $0.setIndex != 2 }
    #expect(DoseAdjustment.propose(plan: plan(), logs: logs, now: day) == nil)
}

@Test("降阶与跳过都不是「多做」")
func downgradedAndSkippedDoNotCount() {
    var logs = twoSessions()
    logs = logs.map { log in
        guard log.setIndex == 1 else { return log }
        var copy = log
        copy.status = .downgraded
        copy.actualValue = copy.plannedValue / 2
        return copy
    }
    #expect(DoseAdjustment.propose(plan: plan(), logs: logs, now: day) == nil)
}

@Test("次数到顶后换下一级杠杆")
func stopsAtCeiling() {
    let nearCeiling = plan(value: 14)
    let next = DoseAdjustment.propose(plan: nearCeiling, logs: twoSessions(planned: 14), now: day)
    #expect(next?.changes[0].field == .sets)

    let atLimit = plan(value: 13)
    #expect(DoseAdjustment.propose(plan: atLimit, logs: twoSessions(planned: 13), now: day)?.changes[0].toValue == 15)
}

@Test("时间型目标不参与加次数")
func ignoresTimedTargets() {
    let timed = plan(value: 40, type: .durationSec)
    #expect(DoseAdjustment.propose(plan: timed, logs: twoSessions(planned: 40), now: day) == nil)
}

@Test("理由要引用具体记录，不许写「根据你的表现」")
func reasonCitesRecords() throws {
    let proposal = try #require(DoseAdjustment.propose(plan: plan(), logs: twoSessions(), now: day))
    #expect(proposal.reason.contains("深蹲"))
    #expect(proposal.reason.contains("至少 1 个"))
    #expect(proposal.reason.contains("根据你的表现") == false)
}

@Test("采纳后计划换数字、版本加一")
func applyBumpsRevisionAndValue() {
    let original = plan()
    let proposal = DoseAdjustment.propose(plan: original, logs: twoSessions(), now: day)!
    let next = DoseAdjustment.apply(proposal, to: original, now: day.addingTimeInterval(60))

    #expect(next.days[0].blocks[0].items[0].target.value == 14)
    #expect(next.revision == original.revision + 1)
    #expect(next.updatedAt == day.addingTimeInterval(60))
    #expect(original.days[0].blocks[0].items[0].target.value == 12)
}

@Test("同一条提案的指纹稳定，改一个数字就不同")
func fingerprintIsStable() {
    let proposal = DoseAdjustment.propose(plan: plan(), logs: twoSessions(), now: day)!
    let same = DoseAdjustment.propose(plan: plan(), logs: twoSessions(), now: day.addingTimeInterval(999))!
    #expect(proposal.fingerprint == same.fingerprint)
    #expect(proposal.fingerprint != PlanProposal(kind: .dose, changes: proposal.changes.map {
        PlanProposal.Change(itemId: $0.itemId, name: $0.name, field: .reps, fromValue: 12, toValue: 16)
    }, reason: proposal.reason, createdAt: day).fingerprint)
}

@Test("采纳之后不会拿旧记录再提一次")
func doesNotRepeatRightAfterAccepting() {
    let original = plan()
    let logs = twoSessions()
    let proposal = DoseAdjustment.propose(plan: original, logs: logs, now: day)!
    let next = DoseAdjustment.apply(proposal, to: original, now: day)
    #expect(DoseAdjustment.propose(plan: next, logs: logs, now: day) == nil)
}
