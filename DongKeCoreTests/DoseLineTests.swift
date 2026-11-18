import Foundation
import Testing

@testable import DongKeCore

struct DoseLineTests {
    private func item(
        type: SetTargetType = .reps,
        value: Int = 12,
        perSide: Bool = false,
        sets: Int = 4
    ) -> ExercisePrescription {
        ExercisePrescription(
            itemId: "p1",
            catalogId: "squat",
            name: "深蹲",
            sets: sets,
            target: SetTarget(type: type, value: value, perSide: perSide),
            restSec: 90
        )
    }

    @Test func bodyweightOmitsWeight() {
        #expect(item().workoutDoseLine(load: nil) == "12 次 × 4 组")
    }

    @Test func dumbbellPrefixedWithWeight() {
        let line = item().workoutDoseLine(load: Load(type: .dumbbell, value: 10))
        #expect(line == "10kg · 12 次 × 4 组")
    }

    @Test func zeroBodyweightLoadStillOmitsWeight() {
        let line = item().workoutDoseLine(load: Load(type: .bodyweight, value: 0))
        #expect(line == "12 次 × 4 组")
    }

    @Test func perSideStaysAfterTheDose() {
        let line = item(perSide: true).workoutDoseLine(load: Load(type: .dumbbell, value: 7.5))
        #expect(line == "7.5kg · 12 次 / 侧 × 4 组")
    }

    @Test func holdTargetUsesSeconds() {
        let line = item(type: .durationSec, value: 45, sets: 3)
            .workoutDoseLine(load: nil)
        #expect(line == "45 秒 × 3 组")
    }

    @Test func bandShowsNameInsteadOfNumber() {
        let line = item().workoutDoseLine(load: Load(type: .band, value: 0))
        #expect(line == "弹力带 · 12 次 × 4 组")
    }
}
