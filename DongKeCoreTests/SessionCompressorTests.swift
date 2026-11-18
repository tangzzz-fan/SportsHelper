import Foundation
import Testing

@testable import DongKeCore

struct SessionCompressorTests {
    private func item(
        _ id: String,
        catalogId: String,
        sets: Int = 4
    ) -> ExercisePrescription {
        ExercisePrescription(
            itemId: id,
            catalogId: catalogId,
            name: catalogId,
            sets: sets,
            target: SetTarget(type: .reps, value: 12, perSide: false),
            restSec: 90
        )
    }

    private func day(_ items: [ExercisePrescription], minutes: Int = 30) -> PlanDay {
        PlanDay(
            dayIndex: 1,
            weekday: .monday,
            isRestDay: false,
            title: "下肢力量",
            scheduledTime: nil,
            estimatedMinutes: minutes,
            blocks: [
                ExerciseBlock(
                    blockId: "b1",
                    kind: .main,
                    title: "主训练",
                    rounds: 1,
                    restBetweenItemsSec: 0,
                    restBetweenRoundsSec: 0,
                    items: items
                )
            ]
        )
    }

    @Test func shortSessionHalvesSetsWithoutTouchingTargets() {
        let original = day([item("i1", catalogId: "squat", sets: 4)], minutes: 20)
        let short = SessionCompressor.compress(original, toMinutes: 10)
        let result = short.blocks.first?.items.first
        #expect(result?.sets == 2)
        #expect(result?.target.value == 12)
        #expect(result?.load == original.blocks.first?.items.first?.load)
        #expect(short.estimatedMinutes == 10)
    }

    @Test func keepsFirstExerciseOfEachGroup() {
        let original = day([
            item("i1", catalogId: "squat"),
            item("i2", catalogId: "lunge"),
            item("i3", catalogId: "push_up"),
            item("i4", catalogId: "plank")
        ])
        let short = SessionCompressor.compress(original, toMinutes: 15)
        let ids = short.blocks.flatMap(\.items).map(\.itemId)
        #expect(ids.contains("i1"))
        #expect(ids.contains("i3"))
        #expect(ids.contains("i4"))
        #expect(ids.contains("i2") == false)
    }

    @Test func neverDropsBelowOneSet() {
        let original = day([item("i1", catalogId: "squat", sets: 1)], minutes: 60)
        let short = SessionCompressor.compress(original, toMinutes: 5)
        #expect(short.blocks.first?.items.first?.sets == 1)
    }

    @Test func zeroMinutesLeavesTheDayAlone() {
        let original = day([item("i1", catalogId: "squat")])
        #expect(SessionCompressor.compress(original, toMinutes: 0) == original)
    }

    @Test func emptyDayIsReturnedUnchanged() {
        let empty = day([], minutes: 30)
        #expect(SessionCompressor.compress(empty, toMinutes: 10) == empty)
    }
}
