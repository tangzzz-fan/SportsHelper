import Foundation
import Testing

@testable import DongKeCore

struct PlanDiffTests {
    private func item(
        _ catalogId: String,
        name: String,
        sets: Int = 3,
        value: Int = 12,
        load: Load = Load(type: .bodyweight, value: 0)
    ) -> ExercisePrescription {
        ExercisePrescription(
            itemId: "i-\(catalogId)",
            catalogId: catalogId,
            name: name,
            sets: sets,
            target: SetTarget(type: .reps, value: value, perSide: false),
            restSec: 90,
            load: load
        )
    }

    private func plan(_ items: [ExercisePrescription]) -> WorkoutPlan {
        makePlan(days: [
            makeDay(index: 1, blocks: [makeBlock(items: items)]),
            makeDay(index: 2, rest: true),
            makeDay(index: 3, rest: true),
            makeDay(index: 4, rest: true),
            makeDay(index: 5, rest: true),
            makeDay(index: 6, rest: true),
            makeDay(index: 7, rest: true)
        ])
    }

    @Test func identicalPlansHaveNoDiff() {
        let base = plan([item("squat", name: "深蹲")])
        #expect(PlanDiff.compare(old: base, new: base).isEmpty)
    }

    @Test func addedExerciseShowsUp() {
        let old = plan([item("squat", name: "深蹲")])
        let new = plan([item("squat", name: "深蹲"), item("lunge", name: "弓步蹲")])
        let diff = PlanDiff.compare(old: old, new: new)
        #expect(diff.lines.contains { $0.kind == .added && $0.text.contains("弓步蹲") })
    }

    @Test func removedExerciseShowsUp() {
        let old = plan([item("squat", name: "深蹲"), item("lunge", name: "弓步蹲")])
        let new = plan([item("squat", name: "深蹲")])
        let diff = PlanDiff.compare(old: old, new: new)
        #expect(diff.lines.contains { $0.kind == .removed && $0.text.contains("弓步蹲") })
    }

    @Test func setsChangeIsSpelledOut() {
        let old = plan([item("squat", name: "深蹲", sets: 3)])
        let new = plan([item("squat", name: "深蹲", sets: 4)])
        let diff = PlanDiff.compare(old: old, new: new)
        #expect(diff.lines.first?.text.contains("3 组 → 4 组") == true)
    }

    @Test func loadChangeIsSpelledOut() {
        let old = plan([item("squat", name: "深蹲", load: Load(type: .dumbbell, value: 8))])
        let new = plan([item("squat", name: "深蹲", load: Load(type: .dumbbell, value: 10))])
        let diff = PlanDiff.compare(old: old, new: new)
        #expect(diff.lines.first?.text.contains("8kg → 10kg") == true)
    }

    @Test func repsChangeIsSpelledOut() {
        let old = plan([item("squat", name: "深蹲", value: 12)])
        let new = plan([item("squat", name: "深蹲", value: 10)])
        let diff = PlanDiff.compare(old: old, new: new)
        #expect(diff.lines.first?.text.contains("12 次 → 10 次") == true)
    }

    @Test func painfulExerciseIsCalledOut() {
        let old = plan([item("squat", name: "深蹲")])
        let new = plan([item("squat", name: "深蹲")])
        let diff = PlanDiff.compare(old: old, new: new, painCatalogIds: ["squat"])
        #expect(diff.painful == ["深蹲"])
    }

    @Test func dayTitleRidesAlong() {
        let old = plan([item("squat", name: "深蹲")])
        let new = plan([item("squat", name: "深蹲"), item("lunge", name: "弓步蹲")])
        #expect(PlanDiff.compare(old: old, new: new).lines.first?.day.isEmpty == false)
    }
}
