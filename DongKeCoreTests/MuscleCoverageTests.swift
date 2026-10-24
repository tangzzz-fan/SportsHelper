import Testing
@testable import DongKeCore

@Suite("主肌群覆盖")
struct MuscleCoverageTests {
    @Test("每个动作都有主肌群")
    func everyEntryHasMuscle() {
        for entry in ExerciseLibrary.all {
            #expect(!entry.primaryMuscles.isEmpty, "\(entry.id) 缺主肌群")
        }
    }

    @Test("主肌群不超过三个")
    func atMostThree() {
        for entry in ExerciseLibrary.all {
            #expect(entry.primaryMuscles.count <= 3, "\(entry.id) 标了 \(entry.primaryMuscles.count) 个")
        }
    }

    @Test("映射表与动作库一一对应")
    func tableMatchesLibrary() {
        #expect(Set(PrimaryMuscleMap.table.keys) == ExerciseLibrary.identifiers)
    }

    @Test("降阶动作与原动作练同一部位")
    func regressionSharesMuscle() {
        for entry in ExerciseLibrary.all {
            guard let id = entry.regressionId, let target = ExerciseLibrary.entry(for: id) else { continue }
            #expect(
                !entry.primaryMuscles.isDisjoint(with: target.primaryMuscles),
                "\(entry.id) 降阶到 \(id)，部位换了"
            )
        }
    }

    @Test("换动作与原动作练同一部位")
    func alternativeSharesMuscle() {
        for entry in ExerciseLibrary.all {
            guard let id = entry.alternativeId, let target = ExerciseLibrary.entry(for: id) else { continue }
            #expect(
                !entry.primaryMuscles.isDisjoint(with: target.primaryMuscles),
                "\(entry.id) 换成 \(id)，部位换了"
            )
        }
    }

    @Test("九个肌群都有动作")
    func everyMuscleHasEntry() {
        for muscle in Muscle.allCases {
            #expect(
                ExerciseLibrary.all.contains { $0.primaryMuscles.contains(muscle) },
                "\(muscle.chineseName) 没有任何动作"
            )
        }
    }

    @Test("主要练的文案按枚举顺序")
    func textOrder() {
        let squat = ExerciseLibrary.entry(for: "squat")
        #expect(squat?.primaryMuscleText == "股四头、臀")
        let rdl = ExerciseLibrary.entry(for: "dumbbell_rdl")
        #expect(rdl?.primaryMuscleText == "腘绳、臀")
    }

    @Test("九个肌群各有至少两个力量动作，闸门全放行")
    func coverageGate() {
        #expect(MuscleCoverage.uncovered.isEmpty)
    }
}
