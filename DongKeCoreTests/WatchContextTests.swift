import Foundation
import Testing
@testable import DongKeCore

private let watchStart = Date(timeIntervalSince1970: 1_770_000_000)

private func makeWatchCheckpoint(
    plan: WorkoutPlan,
    stepIndex: Int = 0,
    revision: Int = 3
) -> WorkoutCheckpoint {
    let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)
    return WorkoutCheckpoint(
        sessionId: UUID(),
        dayIndex: 1,
        stepIndex: stepIndex,
        totalSteps: flow.steps.count,
        startedAt: watchStart,
        updatedAt: watchStart,
        logs: [],
        steps: flow.steps,
        revision: revision
    )
}

private func makeWatchPlan() -> WorkoutPlan {
    let block = makeBlock(items: [
        makeItem(id: "i1", name: "深蹲", sets: 2, value: 12),
        makeItem(id: "i2", name: "平板支撑", sets: 2, value: 30, targetType: .durationSec),
    ])
    return makePlan(days: makeSevenDays(training: [1], blocks: [block]))
}

@Suite("Watch 上下文")
struct WatchContextTests {

    @Test("从快照与计划派生动作名、组数与目标文案")
    func contextBuildsExerciseInfo() throws {
        let plan = makeWatchPlan()
        let checkpoint = makeWatchCheckpoint(plan: plan)

        let context = try #require(WatchContext.make(checkpoint: checkpoint, plan: plan))

        #expect(context.dayTitle == "训练")
        #expect(context.exercises["i1"]?.name == "深蹲")
        #expect(context.exercises["i1"]?.setCount == 2)
        #expect(context.exercises["i1"]?.targetText == "12 次")
        #expect(context.exercises["i2"]?.targetText == "30 秒")
        #expect(context.checkpoint.revision == 3)
        #expect(context.checkpoint.sessionId == checkpoint.sessionId)
    }

    @Test("当前步骤能解析成动作与目标")
    func currentStepResolves() throws {
        let plan = makeWatchPlan()
        let context = try #require(
            WatchContext.make(checkpoint: makeWatchCheckpoint(plan: plan), plan: plan)
        )

        guard case let .set(prescriptionId, setIndex, target, _)? = context.currentStep else {
            Issue.record("第一步应该是组")
            return
        }
        #expect(prescriptionId == "i1")
        #expect(setIndex == 1)
        #expect(target.doseText == "12 次")
        #expect(context.exercise(for: prescriptionId)?.name == "深蹲")
    }

    @Test("没有 steps 的老快照不生成上下文")
    func missingStepsReturnsNil() {
        let plan = makeWatchPlan()
        let checkpoint = WorkoutCheckpoint(
            sessionId: UUID(),
            dayIndex: 1,
            stepIndex: 0,
            totalSteps: 0,
            startedAt: watchStart,
            updatedAt: watchStart
        )

        #expect(WatchContext.make(checkpoint: checkpoint, plan: plan) == nil)
    }

    @Test("往返编码不丢字段")
    func codableRoundTrip() throws {
        let plan = makeWatchPlan()
        let context = try #require(
            WatchContext.make(checkpoint: makeWatchCheckpoint(plan: plan), plan: plan)
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(WatchContext.self, from: data)

        #expect(decoded == context)
    }

    @Test("本地缓存落盘后可读回，删除后为空")
    func contextStoreRoundTrip() throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let plan = makeWatchPlan()
        let context = try #require(
            WatchContext.make(checkpoint: makeWatchCheckpoint(plan: plan), plan: plan)
        )
        let store = WatchContextStore(store: container.store)

        try store.save(context)
        #expect(try store.load() == context)

        try store.remove()
        #expect(try store.load() == nil)
    }
}
