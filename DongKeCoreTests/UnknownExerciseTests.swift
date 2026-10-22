import Testing
import Foundation
@testable import DongKeCore

@Suite("库外与疑似动作")
struct UnknownExerciseTests {

    private func items(_ text: String, memory: AliasMemory = .empty) throws -> [ExercisePrescription] {
        let draft = PlanImportService.parse(text, memory: memory)
        let plan = try #require(draft.plan, "没能编译出计划")
        return plan.days.flatMap(\.blocks).flatMap(\.items)
    }

    @Test("带器械限定词的动作会被标成猜测，但仍然照常计入")
    func materialModifiersAreFlagged() {
        for name in ["杠铃深蹲", "负重深蹲", "箱式深蹲", "相扑深蹲"] {
            let match = ExerciseAliasResolver.match(for: name)
            #expect(match?.catalogId == "squat", "\(name) 应仍归到 squat")
            #expect(match?.needsReview == true, "\(name) 应被标成需要确认")
        }
        #expect(ExerciseAliasResolver.match(for: "杠铃深蹲")?.modifier == "杠铃")
        #expect(ExerciseAliasResolver.match(for: "箱式深蹲")?.modifier == "箱式")
    }

    @Test("变式与单侧限定词同样会被标出来")
    func variantAndUnilateralModifiers() {
        #expect(ExerciseAliasResolver.match(for: "保加利亚分腿蹲")?.catalogId == "lunge")
        #expect(ExerciseAliasResolver.match(for: "保加利亚分腿蹲")?.modifier == "保加利亚")

        #expect(ExerciseAliasResolver.match(for: "单腿臀桥")?.catalogId == "glute_bridge")
        #expect(ExerciseAliasResolver.match(for: "单腿臀桥")?.modifier == "单腿")

        #expect(ExerciseAliasResolver.match(for: "单手哑铃划船")?.modifier == "单手")
    }

    @Test("别名自己就带这个限定词时，不标猜测")
    func coveredModifiersStayQuiet() {
        for name in ["哑铃划船", "哑铃推举", "徒手深蹲", "自重深蹲", "靠墙静蹲", "臀桥", "平板支撑", "开合跳"] {
            #expect(ExerciseAliasResolver.match(for: name)?.needsReview == false, "\(name) 不该被标")
        }
        #expect(ExerciseAliasResolver.match(for: "哑铃划船")?.catalogId == "dumbbell_row")
    }

    @Test("端到端：杠铃深蹲在校对页能被指出，并且计划里仍是深蹲")
    func guessedRowReachesReviewScreen() throws {
        let draft = PlanImportService.parse("周一 杠铃深蹲 5组×5次 100kg")
        let all = try items("周一 杠铃深蹲 5组×5次 100kg")

        #expect(all.count == 1)
        #expect(all[0].catalogId == "squat")
        #expect(all[0].name == "深蹲")
        #expect(draft.guessedItems.count == 1)

        let row = try #require(draft.guessedItems.values.first)
        #expect(row.originalName == "杠铃深蹲")
        #expect(row.catalogName == "深蹲")
        #expect(row.modifier == "杠铃")
        #expect(row.isMemory == false)
        #expect(draft.assumptions.contains { $0.contains("杠铃") && $0.contains("确认") })
    }

    @Test("一行里两个动作：带限定词的那个被标，另一个不受影响")
    func multiItemLineKeepsOthersClean() throws {
        let draft = PlanImportService.parse("周一 杠铃深蹲 4组×8次，臀桥 3组×12次")
        let all = try items("周一 杠铃深蹲 4组×8次，臀桥 3组×12次")

        #expect(all.count == 2)
        #expect(draft.guessedItems.count == 1)
        #expect(all.allSatisfy { $0.catalogId.isEmpty == false })
    }

    @Test("记忆命中时直接用记忆，不再标成猜测")
    func memoryWinsOverGuess() throws {
        var memo = AliasMemory()
        memo.remember("杠铃深蹲", catalogId: "lunge")

        let draft = PlanImportService.parse("周一 杠铃深蹲 5组×5次", memory: memo)
        let all = try items("周一 杠铃深蹲 5组×5次", memory: memo)

        #expect(all[0].catalogId == "lunge")
        #expect(draft.guessedItems.count == 1, "记忆命中也要记下原文名，否则校对页会出现两行「弓步蹲」")
        #expect(draft.guessedItems.values.first?.isMemory == true)
        #expect(draft.guessedItems.values.first?.originalName == "杠铃深蹲")
        #expect(draft.assumptions.contains { $0.contains("上次") })
    }

    @Test("记忆没有命中时回退到别名表")
    func memoryMissFallsBack() {
        var memo = AliasMemory()
        memo.remember("壶铃摆动", catalogId: "glute_bridge")

        #expect(ExerciseAliasResolver.match(for: "深蹲", memory: memo)?.catalogId == "squat")
        #expect(ExerciseAliasResolver.match(for: "壶铃摆动", memory: memo)?.catalogId == "glute_bridge")
        #expect(ExerciseAliasResolver.match(for: "壶铃摆动", memory: memo)?.source == .memory)
    }

    @Test("记忆按归一化后的名字匹配：空格、大小写、标点都不影响")
    func memoryNormalizesNames() {
        var memo = AliasMemory()
        memo.remember("  Kettlebell   Swing ", catalogId: "glute_bridge")

        #expect(memo.catalogId(for: "kettlebell swing") == "glute_bridge")
        #expect(memo.catalogId(for: "KETTLEBELL SWING") == "glute_bridge")
        #expect(memo.count == 1)
    }

    @Test("同一名字记两次只占一条，后写的生效")
    func memoryOverwrites() {
        var memo = AliasMemory()
        memo.remember("壶铃摆动", catalogId: "squat")
        memo.remember("壶铃 摆动", catalogId: "lunge")

        #expect(memo.count == 1)
        #expect(memo.catalogId(for: "壶铃摆动") == "lunge")
    }

    @Test("两份记忆合并时以新的为准")
    func memoryMergePrefersNew() {
        var base = AliasMemory()
        base.remember("壶铃摆动", catalogId: "squat")
        var extra = AliasMemory()
        extra.remember("壶铃摆动", catalogId: "lunge")
        extra.remember("波比跳", catalogId: "jumping_jack")

        let merged = base.merged(with: extra)
        #expect(merged.count == 2)
        #expect(merged.catalogId(for: "壶铃摆动") == "lunge")
        #expect(merged.catalogId(for: "波比跳") == "jumping_jack")
    }

    @Test("别名表只有一份：行扫描与归一化用的是同一张表")
    func singleAliasTable() {
        #expect(ExerciseAliasResolver.aliases.count >= 80)
        #expect(ExerciseAliasResolver.aliases.allSatisfy { ExerciseLibrary.entry(for: $0.id) != nil })
    }

    @Test("自定义动作的 id 与计划里保留原文时的 id 是同一个")
    func customIdIsStable() throws {
        let all = try items("周一 壶铃摆动 4组×15次")
        #expect(all[0].catalogId == CustomExerciseId.id(for: "壶铃摆动"))
        #expect(all[0].catalogId == CustomExerciseId.id(for: " 壶铃 摆动 "))
        #expect(all[0].catalogId.hasPrefix("custom_"))
    }

    @Test("我的动作按名字能查到，大小写和空格不影响")
    func userCatalogLookup() {
        let exercise = UserExercise(name: "Kettlebell Swing", group: .lower, equipment: .kettlebell)
        let catalog = UserExerciseCatalog(exercises: [exercise])

        #expect(catalog.exercise(for: exercise.id)?.name == "Kettlebell Swing")
        #expect(catalog.exercise(named: "kettlebell   swing")?.id == exercise.id)
        #expect(catalog.exercise(named: "壶铃摆动") == nil)
    }

    @Test("同名只留一条，删掉之后查不到")
    func userCatalogDedupeAndRemove() {
        let first = UserExercise(name: "壶铃摆动", group: .lower, equipment: .kettlebell)
        let second = UserExercise(name: "壶铃 摆动", group: .core, equipment: .kettlebell)

        let catalog = UserExerciseCatalog(exercises: [first, second])
        #expect(catalog.exercises.count == 1)
        #expect(catalog.exercises[0].group == .lower)

        #expect(catalog.removing(id: first.id).exercise(named: "壶铃摆动") == nil)
    }

    @Test("我的动作默认剂量：静力按 30 秒，其余的按 12 次")
    func userExerciseDefaults() {
        let hold = UserExercise(name: "靠墙静蹲", group: .lower, isStatic: true)
        #expect(hold.defaultValue == 30)
        #expect(hold.doseUnit == "秒")

        let reps = UserExercise(name: "壶铃摆动", group: .lower)
        #expect(reps.defaultValue == 12)
        #expect(reps.doseUnit == "次")
    }

    @Test("导入时遇到我的动作：指向它、用它的默认剂量，也不再报「不在库里」")
    func compilerUsesMyExercise() throws {
        let mine = UserExercise(
            name: "农夫行走",
            group: .core,
            equipment: .dumbbell,
            isStatic: true,
            defaultSets: 4,
            defaultValue: 40,
            restSec: 75
        )
        let catalog = UserExerciseCatalog(exercises: [mine])
        let draft = PlanImportService.parse("周一 农夫行走 3组", exercises: catalog)

        let plan = try #require(draft.plan)
        let item = try #require(plan.days.flatMap(\.blocks).flatMap(\.items).first)

        #expect(item.catalogId == mine.id)
        #expect(item.name == "农夫行走")
        #expect(item.sets == 3)
        #expect(item.target.type == .durationSec)
        #expect(item.target.value == 40)
        #expect(item.restSec == 75)
        #expect(draft.unmappedNames.isEmpty)
        #expect(draft.assumptions.contains { $0.contains("我的动作") })
    }

    @Test("没保存过的动作仍然按自定义保留，剂量走默认值")
    func compilerKeepsUnknownCustom() throws {
        let draft = PlanImportService.parse("周一 壶铃摆动 3组")
        let plan = try #require(draft.plan)
        let item = try #require(plan.days.flatMap(\.blocks).flatMap(\.items).first)

        #expect(item.catalogId.hasPrefix("custom_"))
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
        #expect(draft.unmappedNames == ["壶铃摆动"])
    }
}
