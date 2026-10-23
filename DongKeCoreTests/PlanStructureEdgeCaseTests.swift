import Foundation
import Testing
@testable import DongKeCore

@Suite("计划拆解：星期与结构")
struct PlanStructureEdgeCaseTests {

    private func plan(_ text: String, exercises: UserExerciseCatalog = .empty) -> WorkoutPlan? {
        PlanImportService.parse(text, exercises: exercises).plan
    }

    private func trainingDays(_ text: String) -> [PlanDay] {
        plan(text)?.days.filter { !$0.isRestDay } ?? []
    }

    @Test("星期、星期几、礼拜、Day N、第 N 天五种写法都归位")
    func weekdaySpellings() {
        let text = "星期一 深蹲 3×12\n礼拜三 臀桥 3×15\nDay 5 平板支撑 30秒\n第 7 天 开合跳 30秒"
        let weekdays = trainingDays(text).map(\.weekday)
        #expect(weekdays == [.monday, .wednesday, .friday, .sunday])
    }

    @Test("没写星期的日子按顺序补周一到周日，并且说出来")
    func unlabeledDaysAssignedInOrder() throws {
        let draft = PlanImportService.parse("深蹲 3×12\n臀桥 3×15")
        let days = try #require(draft.plan?.days.filter { !$0.isRestDay })
        #expect(days.count == 1)
        #expect(days[0].weekday == .monday)
        #expect(draft.assumptions.contains { $0.contains("没写星期") })
    }

    @Test("八天内容只排七天，多出来的动作在假设里点名")
    func overflowIsDropped() throws {
        let text = """
        胸
        深蹲 3×12
        背
        划船 3×12
        腿
        弓步蹲 3×12
        肩
        推举 3×12
        核心
        平板支撑 3组
        有氧
        开合跳 3×30秒
        全身
        臀桥 3×15
        下肢
        深蹲 3×12
        """
        let draft = PlanImportService.parse(text)
        let days = try #require(draft.plan?.days.filter { !$0.isRestDay })
        #expect(days.count == 7)
        #expect(draft.assumptions.contains { $0.contains("略去") })
    }

    @Test("循环写成区块，轮间休息 60 秒")
    func circuitBlock() throws {
        let day = try #require(trainingDays("周一 循环3轮\n深蹲 12次\n臀桥 15次").first)
        let block = try #require(day.blocks.first)
        #expect(block.kind == .circuit)
        #expect(block.rounds == 3)
        #expect(block.restBetweenRoundsSec == 60)
        #expect(block.items.count == 2)
    }

    @Test("静力动作没写时长时按 30 秒，并写进假设")
    func staticDefaultHold() throws {
        let draft = PlanImportService.parse("周一 平板支撑 3组")
        let item = try #require(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first)
        #expect(item.target.type == .durationSec)
        #expect(item.target.value == 30)
        #expect(draft.assumptions.contains { $0.contains("30 秒") })
    }

    @Test("库外动作保留原文并给稳定的 custom_ 标识")
    func customExerciseSlug() throws {
        let draft = PlanImportService.parse("周一 壶铃摆动 3组")
        let item = try #require(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first)
        #expect(item.catalogId.hasPrefix("custom_"))
        #expect(item.catalogId == CustomExerciseId.id(for: "壶铃摆动"))
        #expect(item.name == "壶铃摆动")
        #expect(draft.unmappedNames == ["壶铃摆动"])
    }

    @Test("我的动作补上默认组数、剂量与休息")
    func myExerciseFillsDefaults() throws {
        let mine = UserExercise(
            name: "壶铃摆动",
            group: .core,
            equipment: .dumbbell,
            isStatic: false,
            defaultSets: 4,
            defaultValue: 20,
            restSec: 45
        )
        let draft = PlanImportService.parse("周一 壶铃摆动 3组", exercises: UserExerciseCatalog(exercises: [mine]))
        let item = try #require(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first)
        #expect(item.catalogId == mine.id)
        #expect(item.sets == 3)
        #expect(item.target.value == 20)
        #expect(item.restSec == 45)
        #expect(draft.assumptions.contains { $0.contains("我的动作") })
    }

    @Test("没写注意事项时给一条默认安全提示")
    func defaultCautions() {
        #expect(plan("周一 深蹲 3×12")?.cautions == ["关节疼痛须停训，动作幅度以无痛为限"])
    }

    @Test("每周训练天数与训练日数量一致")
    func daysPerWeekMatches() {
        let text = "周一 深蹲 3×12\n周三 臀桥 3×15\n周五 开合跳 3×30秒"
        let built = plan(text)
        #expect(built?.meta.daysPerWeek == trainingDays(text).count)
        #expect(PlanValidator.validate(built!).isEmpty)
    }

    @Test("估算时长随组数增长，且至少一分钟")
    func estimatedMinutes() throws {
        let light = try #require(trainingDays("周一 深蹲 2×10").first)
        let heavy = try #require(trainingDays("周一 深蹲 5×20").first)
        #expect(light.estimatedMinutes >= 1)
        #expect(heavy.estimatedMinutes > light.estimatedMinutes)
    }

    @Test("itemId 按「第几天-第几个」稳定生成")
    func itemIdsAreStable() throws {
        let monday = try #require(trainingDays("周一 深蹲 3×12\n臀桥 3×15\n划船 3×10").first)
        let ids = try #require(monday.blocks.first).items.map(\.itemId)
        #expect(ids == ["d1-i1", "d1-i2", "d1-i3"])
    }

    @Test("没写休息时统一按 60 秒")
    func defaultRest() throws {
        let item = try #require(trainingDays("周一 深蹲 3×12").first?.blocks.first?.items.first)
        #expect(item.restSec == 60)
    }
}
