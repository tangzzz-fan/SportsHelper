import Testing
import Foundation
@testable import DongKeCore

@Suite("ExerciseLibrary")
struct ExerciseLibraryTests {

    @Test("18 个动作，id 唯一")
    func countAndUniqueness() {
        #expect(ExerciseLibrary.all.count == 18)
        #expect(Set(ExerciseLibrary.all.map(\.id)).count == 18)
    }

    @Test("动作库与计划生成器用的是同一套 id")
    func idsMatchGeneratorCatalog() {
        let library = Set(ExerciseLibrary.all.map(\.id))
        let generator = Set(PlanGenerator.catalog.map(\.id))
        #expect(library == generator)
    }

    @Test("每个动作都有图示，不是占位图")
    func everyEntryHasFigure() {
        for entry in ExerciseLibrary.all {
            let figure = FigureLibrary.bundled.figure(for: entry.id)
            #expect(figure.catalogId == entry.id, "\(entry.id) 没有自己的素材")
            #expect(figure.frames.isEmpty == false)
        }
    }

    @Test("要点与常见错误都不为空")
    func contentIsFilled() {
        for entry in ExerciseLibrary.all {
            #expect(entry.cues.count >= 2, "\(entry.id) 要点太少")
            #expect(entry.mistakes.isEmpty == false, "\(entry.id) 没有常见错误")
            #expect(entry.regressionName.isEmpty == false, "\(entry.id) 没有低阶替代")
            #expect(entry.name.isEmpty == false)
        }
    }

    @Test("低阶替代若指向库内动作，必须存在且不是自己")
    func regressionIsValid() {
        for entry in ExerciseLibrary.all {
            guard let id = entry.regressionId else { continue }
            #expect(id != entry.id, "\(entry.id) 的低阶替代指向自己")
            #expect(ExerciseLibrary.entry(for: id) != nil, "\(entry.id) 的低阶替代 \(id) 不在库内")
        }
    }

    @Test("未知 id 返回 nil，分组覆盖全部动作")
    func lookupAndGrouping() {
        #expect(ExerciseLibrary.entry(for: "squat")?.name == "深蹲")
        #expect(ExerciseLibrary.entry(for: "burpee") == nil)

        let grouped = ExerciseLibrary.grouped()
        #expect(grouped.count == ExerciseGroup.allCases.count)
        #expect(grouped.reduce(0) { $0 + $1.entries.count } == ExerciseLibrary.all.count)
        for group in grouped {
            #expect(group.entries.allSatisfy { $0.group == group.group })
        }
    }
}
