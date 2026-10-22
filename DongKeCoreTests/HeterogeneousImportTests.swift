import Testing
import Foundation
@testable import DongKeCore

@Suite("异构计划导入")
struct HeterogeneousImportTests {

    private func plan(from text: String) throws -> WorkoutPlan {
        let draft = PlanImportService.parse(text)
        return try #require(draft.plan, "没能从这段内容编译出计划")
    }

    private func itemsIn(_ plan: WorkoutPlan, _ weekday: Weekday) -> [ExercisePrescription] {
        plan.days.first(where: { $0.weekday == weekday })?.blocks.flatMap(\.items) ?? []
    }

    private func item(_ items: [ExercisePrescription], _ index: Int) throws -> ExercisePrescription {
        try #require(items.indices.contains(index), "第 \(index) 个动作不存在，实际 \(items.count) 个")
        return items[index]
    }

    @Test("ChatGPT 式 JSON：键名不统一、次数是区间、休息叫 rest_seconds")
    func genericAgentJSON() throws {
        let json = #"""
        {
          "planName": "8 周增肌 · 第 1 周",
          "days": [
            {
              "day": "周一",
              "title": "下肢",
              "exercises": [
                {"exercise": "深蹲", "sets": 4, "reps": "8-12", "rest_seconds": 90},
                {"name": "罗马尼亚硬拉", "sets": 3, "reps": 10}
              ]
            },
            {
              "day": "周四",
              "exercises": [
                {"name": "push-up", "sets": "3组", "reps": "12次"}
              ]
            }
          ]
        }
        """#

        let draft = PlanImportService.parse(json)
        #expect(draft.path == .lenientJSON)
        let plan = try plan(from: json)
        #expect(plan.meta.title == "8 周增肌 · 第 1 周")

        let monday = itemsIn(plan, .monday)
        #expect(monday.count == 2)
        #expect(try item(monday, 0).catalogId == "squat")
        #expect(try item(monday, 0).sets == 4)
        #expect(try item(monday, 0).target.value == 8)
        #expect(try item(monday, 0).restSec == 90)
        #expect(try item(monday, 1).name == "罗马尼亚硬拉")
        #expect(try item(monday, 1).catalogId.hasPrefix("custom_"))

        let thursday = itemsIn(plan, .thursday)
        #expect(thursday.count == 1)
        #expect(thursday[0].catalogId == "push_up")
        #expect(thursday[0].sets == 3)
        #expect(thursday[0].target.value == 12)

        #expect(draft.assumptions.contains { $0.contains("8-12") })
        #expect(draft.unmappedNames.contains("罗马尼亚硬拉"))
    }

    @Test("JSON 套在 weeks → days 下面也能认出来")
    func nestedWeeksJSON() throws {
        let json = #"""
        {"weeks":[{"week":1,"days":[
          {"weekday":"Tuesday","exercises":[{"movement":"plank","durationSec":45}]}
        ]}]}
        """#
        let plan = try plan(from: json)
        let tuesday = itemsIn(plan, .tuesday)
        #expect(tuesday.count == 1)
        #expect(try item(tuesday, 0).catalogId == "plank")
        #expect(try item(tuesday, 0).target.type == .durationSec)
        #expect(try item(tuesday, 0).target.value == 45)
    }

    @Test("Claude 式 Markdown 表格：表头列错位也不怕")
    func markdownTable() throws {
        let text = #"""
        ## 周一 · 下肢

        | 动作 | 组数 | 次数 | 休息 |
        | --- | --- | --- | --- |
        | 深蹲 | 4 | 10 | 90s |
        | 臀桥 | 3 | 15 | 1min |
        """#
        let plan = try plan(from: text)
        let monday = itemsIn(plan, .monday)
        #expect(monday.count == 2)
        #expect(try item(monday, 0).sets == 4)
        #expect(try item(monday, 0).target.value == 10)
        #expect(try item(monday, 0).restSec == 90)
        #expect(try item(monday, 1).catalogId == "glute_bridge")
        #expect(try item(monday, 1).restSec == 60)
    }

    @Test("列表 + Day 标题：Day 1 落周一，Day 3 落周三")
    func dayHeadingsList() throws {
        let text = """
        ### Day 1 — Upper
        - Bench Press 3x10 rest 90s
        - Push-up 3x12

        ### Day 3
        - Plank 3 x 45s
        """
        let plan = try plan(from: text)
        let monday = itemsIn(plan, .monday)
        #expect(monday.count == 2)
        #expect(try item(monday, 0).name == "Bench Press")
        #expect(try item(monday, 0).restSec == 90)
        #expect(try item(monday, 1).catalogId == "push_up")

        let wednesday = itemsIn(plan, .wednesday)
        #expect(wednesday.count == 1)
        #expect(try item(wednesday, 0).catalogId == "plank")
        #expect(try item(wednesday, 0).target.value == 45)
    }

    @Test("散文里一天一句也能拆开，注意行进注意事项")
    func proseWithMultipleDays() throws {
        let text = "这是一套适合新手的计划。周一先做深蹲4组12次，然后做弓步蹲每侧10次，组间休息90秒。周三做平板支撑3组每组45秒。注意膝盖不要内扣。"
        let draft = PlanImportService.parse(text)
        let plan = try #require(draft.plan)

        let monday = itemsIn(plan, .monday)
        #expect(monday.count == 2)
        #expect(try item(monday, 0).catalogId == "squat")
        #expect(try item(monday, 0).sets == 4)
        #expect(try item(monday, 0).target.value == 12)
        #expect(try item(monday, 1).catalogId == "lunge")
        #expect(try item(monday, 1).target.perSide)
        #expect(try item(monday, 1).restSec == 90)

        let wednesday = itemsIn(plan, .wednesday)
        #expect(wednesday.count == 1)
        #expect(try item(wednesday, 0).catalogId == "plank")
        #expect(try item(wednesday, 0).sets == 3)
        #expect(try item(wednesday, 0).target.value == 45)

        #expect(plan.cautions.contains { $0.contains("膝盖") })
    }

    @Test("只写了动作名时按默认剂量补，并把每一处假设说出来")
    func defaultsAreDeclared() {
        let draft = PlanDraft(
            title: nil,
            days: [
                DraftDay(order: 1, label: "周一", weekday: .monday, items: [
                    DraftItem(rawName: "深蹲")
                ])
            ],
            cautions: [],
            source: .lineScan
        )
        let compiled = PlanDraftCompiler.compile(draft)
        let item = compiled.plan.days[0].blocks[0].items[0]

        #expect(item.sets == PlanDraftCompiler.defaultSets)
        #expect(item.target.value == PlanDraftCompiler.defaultReps)
        #expect(item.restSec == PlanDraftCompiler.defaultRestSeconds)
        #expect(compiled.assumptions.count >= 3)
        #expect(compiled.assumptions.contains { $0.contains("组数") })
        #expect(compiled.assumptions.contains { $0.contains("休息") })
    }

    @Test("别名表：中文口语、英文名、器械前缀都归到同一动作")
    func aliasVariants() {
        #expect(ExerciseAliasResolver.catalogId(for: "徒手深蹲") == "squat")
        #expect(ExerciseAliasResolver.catalogId(for: "Bodyweight Squat") == "squat")
        #expect(ExerciseAliasResolver.catalogId(for: "保加利亚分腿蹲") == "lunge")
        #expect(ExerciseAliasResolver.catalogId(for: "Bulgarian Split Squat") == "lunge")
        #expect(ExerciseAliasResolver.catalogId(for: "侧平板支撑") == "side_plank")
        #expect(ExerciseAliasResolver.catalogId(for: "哑铃划船") == "dumbbell_row")
        #expect(ExerciseAliasResolver.catalogId(for: "Bench Press") == nil)
    }

    @Test("同一天写两次会合并，不会覆盖")
    func duplicateWeekdayMerges() {
        let draft = PlanDraft(
            days: [
                DraftDay(order: 1, label: "周一", weekday: .monday, items: [DraftItem(rawName: "深蹲", sets: 4)]),
                DraftDay(order: 2, label: "周一", weekday: .monday, items: [DraftItem(rawName: "臀桥", sets: 3)])
            ],
            source: .lineScan
        )
        let compiled = PlanDraftCompiler.compile(draft)
        let monday = compiled.plan.days.first { $0.weekday == .monday }
        #expect(monday?.blocks.flatMap(\.items).count == 2)
        #expect(compiled.assumptions.contains { $0.contains("合并") })
    }

    @Test("识别不出的动作保留原名，不丢")
    func keepsUnknownNames() throws {
        let plan = try plan(from: "周一 保加利亚分腿蹲 3组 每侧8次\n周二 农夫行走 3组 40米")
        let monday = itemsIn(plan, .monday)
        #expect(monday.first?.catalogId == "lunge")

        let tuesday = itemsIn(plan, .tuesday)
        #expect(tuesday.first?.name == "农夫行走")
        #expect(tuesday.first?.catalogId.hasPrefix("custom_") == true)
    }

    @Test("发布给 AI 的提示词本身能被自己的解析器读懂")
    func promptTemplateIsParseable() throws {
        let text = PlanPromptTemplate.text
        #expect(text.contains("days"))
        #expect(text.contains("restSec"))

        let json = try #require(PlanJSONExtractor.extract(from: text))
        let plan = try plan(from: json)
        #expect(plan.meta.title == "8 周增肌 · 第 1 周")
        #expect(itemsIn(plan, .monday).count == 2)
        let wednesday = itemsIn(plan, .wednesday)
        #expect(wednesday.count == 1)
        #expect(wednesday[0].catalogId == "plank")
        #expect(wednesday[0].target.value == 45)
    }
}
