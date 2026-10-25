import Foundation
import Testing
@testable import DongKeCore

private let extraDay = Date(timeIntervalSince1970: 1_770_000_000)

private func extraPlan() -> WorkoutPlan {
    makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [
        makeItem(id: "i1", sets: 3, value: 12)
    ])])])
}

private func extraTarget() -> SetTarget {
    SetTarget(type: .reps, value: 12, perSide: false)
}

@Suite("加组脚本")
struct ExtraSetFlowTests {

    @Test("在某一组之后插入额外组，位置紧挨着它")
    func insertsAfterSet() {
        let flow = WorkoutFlowModel(plan: extraPlan(), dayIndex: 1)
        let next = WorkoutFlowModel.insertingExtraSet(
            in: flow.steps,
            after: 2,
            prescriptionId: "i1",
            setIndex: 4,
            target: extraTarget(),
            restAfterSec: 90
        )
        #expect(next.count == flow.steps.count + 1)
        if case let .set(id, setIndex, _, rest) = next[3] {
            #expect(id == "i1")
            #expect(setIndex == 4)
            #expect(rest == 90)
        } else {
            Issue.record("第 4 步应是额外组")
        }
        #expect(next.last == .finished)
    }

    @Test("插在最后一组之后仍然排在 finished 前面")
    func insertsBeforeFinished() {
        let flow = WorkoutFlowModel(plan: extraPlan(), dayIndex: 1)
        let lastSetIndex = flow.steps.count - 2
        let next = WorkoutFlowModel.insertingExtraSet(
            in: flow.steps,
            after: lastSetIndex,
            prescriptionId: "i1",
            setIndex: 4,
            target: extraTarget(),
            restAfterSec: 90
        )
        if case let .set(_, setIndex, _, _) = next[next.count - 2] {
            #expect(setIndex == 4)
        } else {
            Issue.record("额外组应在 finished 前")
        }
        #expect(next.last == .finished)
    }

    @Test("索引越界或不是组时原样返回")
    func ignoresNonSetAnchor() {
        let flow = WorkoutFlowModel(plan: extraPlan(), dayIndex: 1)
        #expect(WorkoutFlowModel.insertingExtraSet(
            in: flow.steps,
            after: flow.steps.count - 1,
            prescriptionId: "i1",
            setIndex: 4,
            target: extraTarget(),
            restAfterSec: 90
        ) == flow.steps)
        #expect(WorkoutFlowModel.insertingExtraSet(
            in: flow.steps,
            after: 99,
            prescriptionId: "i1",
            setIndex: 4,
            target: extraTarget(),
            restAfterSec: 90
        ) == flow.steps)
    }

    @Test("播报的分母仍是计划组数，额外组只把这一组的序号与总数顶上去")
    func announcementKeepsPlannedDenominator() throws {
        let plan = extraPlan()
        let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)
        let script = WorkoutFlowModel.insertingExtraSet(
            in: flow.steps,
            after: 2,
            prescriptionId: "i1",
            setIndex: 4,
            target: extraTarget(),
            restAfterSec: 90
        )
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1, steps: script)
        #expect(builder.plannedSets == 3)

        let announcement = try #require(builder.announcement(forStepAt: 3))
        guard case let .setStart(_, setIndex, totalSets, _, _) = announcement else {
            Issue.record("应是组开始播报")
            return
        }
        #expect(setIndex == 4)
        #expect(totalSets == 4)
    }

    @Test("旧 checkpoint 没有 steps 字段时解码为 nil")
    func legacyCheckpointHasNoSteps() throws {
        let flow = WorkoutFlowModel(plan: extraPlan(), dayIndex: 1)
        let checkpoint = WorkoutCheckpoint(
            sessionId: UUID(),
            dayIndex: 1,
            stepIndex: 1,
            totalSteps: flow.steps.count,
            startedAt: extraDay,
            updatedAt: extraDay,
            steps: flow.steps
        )
        let data = try JSONEncoder().encode(checkpoint)
        let raw = try JSONSerialization.jsonObject(with: data)
        var object = try #require(raw as? [String: Any])
        object.removeValue(forKey: "steps")
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WorkoutCheckpoint.self, from: stripped)
        #expect(decoded.steps == nil)
        #expect(decoded.stepIndex == 1)
    }

    @Test("带额外组的 checkpoint 往返后脚本不丢")
    func checkpointKeepsScript() throws {
        let flow = WorkoutFlowModel(plan: extraPlan(), dayIndex: 1)
        let script = WorkoutFlowModel.insertingExtraSet(
            in: flow.steps,
            after: 2,
            prescriptionId: "i1",
            setIndex: 4,
            target: extraTarget(),
            restAfterSec: 90
        )
        let checkpoint = WorkoutCheckpoint(
            sessionId: UUID(),
            dayIndex: 1,
            stepIndex: 2,
            totalSteps: script.count,
            startedAt: extraDay,
            updatedAt: extraDay,
            steps: script
        )
        let decoded = try JSONDecoder().decode(
            WorkoutCheckpoint.self,
            from: JSONEncoder().encode(checkpoint)
        )
        #expect(decoded.steps == script)
        #expect(decoded.totalSteps == script.count)
    }
}
