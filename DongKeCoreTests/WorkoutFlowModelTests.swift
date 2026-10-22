import Testing
@testable import DongKeCore

@Suite("WorkoutFlowModel")
struct WorkoutFlowModelTests {
    @Test func expandsThreeExercisesThreeSets() throws {
        let items = [makeItem(id: "i1"), makeItem(id: "i2"), makeItem(id: "i3")]
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: items)]))
        let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)

        #expect(flow.plannedSets == 9)
        #expect(flow.steps.last == .finished)

        let first = try #require(flow.steps.first)
        if case .set(let prescriptionId, let setIndex, _, let rest) = first {
            #expect(prescriptionId == "i1")
            #expect(setIndex == 1)
            #expect(rest == 90)
        } else {
            Issue.record("首个步骤应为 set")
        }
    }

    @Test func expandsCircuitRounds() {
        let items = [makeItem(id: "i1", sets: 1), makeItem(id: "i2", sets: 1)]
        let block = makeBlock(kind: .circuit, rounds: 3, items: items, restBetweenRounds: 60)
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [block]))
        let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)

        #expect(flow.plannedSets == 6)
        let roundBreaks = flow.steps.filter {
            if case .roundBreak = $0 { true } else { false }
        }.count
        #expect(roundBreaks == 2)
    }

    @Test func expandsSupersetWithZeroRest() throws {
        let items = [makeItem(id: "i1", sets: 1, rest: 0), makeItem(id: "i2", sets: 1, rest: 0)]
        let block = makeBlock(kind: .superset, rounds: 3, items: items, restBetweenItems: 0)
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [block]))
        let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)

        #expect(flow.plannedSets == 6)
        let first = try #require(flow.steps.first)
        if case .set(_, _, _, let rest) = first {
            #expect(rest == 0)
        }
    }

    @Test func restDayHasNoSets() {
        let plan = makePlan(days: makeSevenDays(training: [], blocks: []))
        let flow = WorkoutFlowModel(plan: plan, dayIndex: 2)

        #expect(flow.plannedSets == 0)
        #expect(flow.steps == [.finished])
    }
}
