import Testing
import Foundation
@testable import DongKeCore

@Suite("动作合并表")
struct ExerciseMergeMapTests {

    @Test("直接重定向")
    func directRedirect() {
        let map = ExerciseMergeMap(redirects: ["old_squat": "squat"])
        #expect(map.resolve("old_squat") == "squat")
        #expect(map.resolve("squat") == "squat")
        #expect(map.resolve("burpee") == "burpee")
        #expect(map.count == 1)
    }

    @Test("链式重定向一路折到底，不停在中转站")
    func chainedRedirectFoldsAllTheWay() {
        let map = ExerciseMergeMap(redirects: [
            "squat_v1": "squat_v2",
            "squat_v2": "squat_v3",
            "squat_v3": "squat",
        ])
        #expect(map.resolve("squat_v1") == "squat")
        #expect(map.resolve("squat_v2") == "squat")
        #expect(map.resolve("squat_v3") == "squat")
        #expect(map.cycles.isEmpty)
    }

    @Test("成环时原样返回，不猜终点，也不死循环")
    func cycleReturnsSource() {
        let map = ExerciseMergeMap(redirects: [
            "a": "b",
            "b": "a",
        ])
        #expect(map.resolve("a") == "a")
        #expect(map.resolve("b") == "b")
        #expect(map.cycles == ["a", "b"])
    }

    @Test("自映射与空白条目被丢掉")
    func selfMapAndBlankAreDropped() {
        let map = ExerciseMergeMap(redirects: [
            "squat": "squat",
            "": "squat",
            "lunge": "",
            "  ": "lunge",
        ])
        #expect(map.isEmpty)
        #expect(map.resolve("squat") == "squat")
        #expect(map.resolve("") == "")
    }

    @Test("批量折叠后去重，且保持首次出现的顺序")
    func mergingDedupesAndKeepsOrder() {
        let map = ExerciseMergeMap(redirects: ["old_row": "dumbbell_row"])
        let merged = map.merging(["squat", "old_row", "lunge", "dumbbell_row", "squat"])
        #expect(merged == ["squat", "dumbbell_row", "lunge"])
    }

    @Test("目标不在动作库里能被查出来")
    func danglingTargetsAreReported() {
        let map = ExerciseMergeMap(redirects: [
            "old_a": "squat",
            "old_b": "gone_forever",
        ])
        let dangling = map.danglingTargets(in: ["squat", "lunge"])
        #expect(dangling == ["old_b"])
    }

    @Test("旧 id 仍能查到动作条目")
    func libraryResolvesLegacyId() {
        let map = ExerciseMergeMap(redirects: ["legacy_pushup": "push_up"])
        #expect(ExerciseLibrary.entry(for: "legacy_pushup", merging: map)?.name == "俯卧撑")
        #expect(ExerciseLibrary.entry(for: "legacy_pushup") == nil)
        #expect(ExerciseLibrary.entry(for: "push_up", merging: map)?.id == "push_up")
    }

    @Test("合并表不得把现存动作藏到不存在的目标上")
    func mergeMapTargetsExist() {
        for (source, target) in ExerciseMergeMap.current.pairs {
            #expect(ExerciseLibrary.identifiers.contains(target), "\(source) 折到了库外的 \(target)")
        }
        #expect(ExerciseMergeMap.current.cycles.isEmpty, "合并表成环：\(ExerciseMergeMap.current.cycles)")
    }

    @Test("折叠后的 id 都能在库里找到")
    func everyResolvedIdExists() {
        for entry in ExerciseLibrary.all {
            #expect(ExerciseLibrary.entry(for: entry.id)?.id == entry.id)
        }
    }
}
