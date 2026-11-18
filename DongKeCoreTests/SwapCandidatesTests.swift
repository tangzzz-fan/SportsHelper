import Foundation
import Testing

@testable import DongKeCore

struct SwapCandidatesTests {
    private func item(
        _ id: String,
        catalogId: String,
        sets: Int = 4,
        load: Load = Load(type: .bodyweight, value: 0)
    ) -> ExercisePrescription {
        ExercisePrescription(
            itemId: id,
            catalogId: catalogId,
            name: catalogId,
            sets: sets,
            target: SetTarget(type: .reps, value: 12, perSide: false),
            restSec: 90,
            load: load
        )
    }

    @Test func regressionComesFirst() {
        let suggestions = SwapCandidates.suggestions(
            for: item("i1", catalogId: "lunge"),
            available: [.bodyweight, .dumbbell]
        )
        #expect(suggestions.first?.id == "squat")
    }

    @Test func neverSuggestsItself() {
        let suggestions = SwapCandidates.suggestions(
            for: item("i1", catalogId: "squat"),
            available: Equipment.allCases
        )
        #expect(suggestions.contains { $0.id == "squat" } == false)
    }

    @Test func respectsAvailableEquipment() {
        let suggestions = SwapCandidates.suggestions(
            for: item("i1", catalogId: "dumbbell_row", load: Load(type: .dumbbell, value: 8)),
            available: [.bodyweight]
        )
        #expect(suggestions.isEmpty == false)
        #expect(suggestions.allSatisfy { $0.equipment == .bodyweight })
    }

    @Test func sameMuscleGroupOnly() {
        let suggestions = SwapCandidates.suggestions(
            for: item("i1", catalogId: "squat"),
            available: Equipment.allCases
        )
        #expect(suggestions.allSatisfy { $0.group == .lower })
    }

    @Test func keepsTheMetricType() {
        // 静态动作不能换成动态动作：次数与秒数没法记在同一条纪录里。
        let suggestions = SwapCandidates.suggestions(
            for: item("i1", catalogId: "plank"),
            available: Equipment.allCases
        )
        #expect(suggestions.allSatisfy { $0.isStatic })
    }

    @Test func capsAtThree() {
        let suggestions = SwapCandidates.suggestions(
            for: item("i1", catalogId: "squat"),
            available: Equipment.allCases
        )
        #expect(suggestions.count <= SwapCandidates.limit)
    }

    @Test func unknownCatalogGivesNoSuggestions() {
        #expect(SwapCandidates.suggestions(for: item("i1", catalogId: "not_real"), available: Equipment.allCases).isEmpty)
    }

    @Test func replacementKeepsItemIdAndSwapsCatalog() {
        let original = item("i1", catalogId: "dumbbell_row", load: Load(type: .dumbbell, value: 8))
        let entry = ExerciseLibrary.entry(for: "squat")!
        let next = SwapCandidates.prescription(replacing: original, with: entry)
        #expect(next.itemId == "i1")
        #expect(next.catalogId == "squat")
        #expect(next.name == entry.name)
        #expect(next.sets == original.sets)
        #expect(next.target == original.target)
    }

    @Test func bodyweightReplacementClearsLoad() {
        let original = item("i1", catalogId: "dumbbell_row", load: Load(type: .dumbbell, value: 8))
        let entry = ExerciseLibrary.entry(for: "squat")!
        let next = SwapCandidates.prescription(replacing: original, with: entry)
        #expect(next.load == Load(type: .bodyweight, value: 0))
    }
}
