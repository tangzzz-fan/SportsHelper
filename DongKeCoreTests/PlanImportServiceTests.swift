import Testing
import Foundation
@testable import DongKeCore

@Suite("PlanImportService")
struct PlanImportServiceTests {

    private func generatedPlan() -> WorkoutPlan {
        var profile = UserProfile()
        profile.availableWeekdays = [.monday, .wednesday]
        profile.sessionMinutes = 30
        return PlanGenerator.makePlan(profile: profile)
    }

    private func json(of plan: WorkoutPlan) throws -> String {
        let data = try JSONEncoder().encode(plan)
        return String(decoding: data, as: UTF8.self)
    }

    @Test("合法 JSON 走严格解码，不做正则解析")
    func strictJSONPath() throws {
        let plan = generatedPlan()
        let draft = PlanImportService.parse(try json(of: plan))

        #expect(draft.path == .strictJSON)
        let parsed = try #require(draft.plan)
        #expect(parsed.days.count == 7)
        #expect(parsed.meta.title == plan.meta.title)
        #expect(draft.issues.contains { $0.severity == .error } == false)
    }

    @Test("缺可选字段的 JSON 走宽容解码并给出提醒")
    func lenientJSONPath() throws {
        let plan = generatedPlan()
        var root = try #require(
            try JSONSerialization.jsonObject(with: Data(try json(of: plan).utf8)) as? [String: Any]
        )
        root.removeValue(forKey: "cautions")
        if var meta = root["meta"] as? [String: Any] {
            meta.removeValue(forKey: "notes")
            root["meta"] = meta
        }
        let data = try JSONSerialization.data(withJSONObject: root)
        let draft = PlanImportService.parse(String(decoding: data, as: UTF8.self))

        #expect(draft.path == .lenientJSON)
        #expect(draft.plan != nil)
        #expect(draft.issues.contains { $0.severity == .warning })
    }

    @Test("纯文本按自由文本解析，组数次数休息都要对上")
    func freeTextPath() throws {
        let draft = PlanImportService.parse("周一\n深蹲 4组×12次，休息90秒")

        #expect(draft.path == .freeText)
        let plan = try #require(draft.plan)
        let monday = try #require(plan.days.first(where: { $0.weekday == .monday }))
        let item = try #require(monday.blocks.first?.items.first)
        #expect(item.sets == 4)
        #expect(item.target.type == .reps)
        #expect(item.target.value == 12)
        #expect(item.restSec == 90)
        #expect(item.catalogId == "squat")
        #expect(draft.issues.contains { $0.severity == .error } == false)
    }

    @Test("像 JSON 但结构不对时，不假装识别成功")
    func malformedJSON() {
        let draft = PlanImportService.parse(#"{"days": 3}"#)
        #expect(draft.plan == nil)
        #expect(draft.path == .lenientJSON)
        #expect(draft.hasBlockingIssues)
    }

    @Test("空白内容给出提示而不是系统错误")
    func blankInput() {
        let draft = PlanImportService.parse("   \n  ")
        #expect(draft.plan == nil)
        #expect(draft.path == .blank)
        #expect(draft.issues.first?.message.contains("粘贴") == true)
    }

    @Test("识别不出动作时提示未能识别")
    func unrecognizedText() {
        let draft = PlanImportService.parse("今天练一下胸吧，随便练练")
        #expect(draft.plan == nil)
        #expect(draft.hasBlockingIssues)
        #expect(draft.issues.first?.message.contains("未能") == true)
    }

    @Test("超过 64KB 的内容被挡下")
    func oversizedInput() {
        let draft = PlanImportService.parse(String(repeating: "深蹲 3组×12次\n", count: 6000))
        #expect(draft.plan == nil)
        #expect(draft.issues.first?.message.contains("64KB") == true)
    }
}

@Suite("PlanEditing")
struct PlanEditingTests {

    private func planWithItems() -> (WorkoutPlan, Int, String) {
        var profile = UserProfile()
        profile.availableWeekdays = [.monday, .wednesday, .friday]
        profile.sessionMinutes = 30
        let plan = PlanGenerator.makePlan(profile: profile)
        let day = plan.days.first { !$0.isRestDay }!
        let item = day.blocks.first!.items.first!
        return (plan, day.dayIndex, item.itemId)
    }

    @Test("只改目标行，其他行不动")
    func updatesOnlyTargetItem() {
        let (plan, dayIndex, itemId) = planWithItems()
        let updated = PlanEditing.updateItem(in: plan, dayIndex: dayIndex, itemId: itemId, sets: 6)

        let before = plan.days.first { $0.dayIndex == dayIndex }!
        let after = updated.days.first { $0.dayIndex == dayIndex }!

        #expect(after.blocks.first?.items.first?.sets == 6)
        for (b, a) in zip(before.blocks.flatMap(\.items).dropFirst(), after.blocks.flatMap(\.items).dropFirst()) {
            #expect(b == a)
        }
        for day in plan.days where day.dayIndex != dayIndex {
            #expect(updated.days.first { $0.dayIndex == day.dayIndex } == day)
        }
    }

    @Test("改次数时保留目标类型（时长动作仍是秒）")
    func keepsTargetType() {
        let (plan, dayIndex, itemId) = planWithItems()
        let before = plan.days.first { $0.dayIndex == dayIndex }!
            .blocks.flatMap(\.items).first { $0.itemId == itemId }!
        let updated = PlanEditing.updateItem(in: plan, dayIndex: dayIndex, itemId: itemId, value: 20)
        let after = updated.days.first { $0.dayIndex == dayIndex }!
            .blocks.flatMap(\.items).first { $0.itemId == itemId }!

        #expect(after.target.type == before.target.type)
        #expect(after.target.value == 20)
    }

    @Test("组数下限为 1，休息下限为 0")
    func clampsInput() {
        let (plan, dayIndex, itemId) = planWithItems()
        let updated = PlanEditing.updateItem(
            in: plan, dayIndex: dayIndex, itemId: itemId, sets: 0, restSec: -30
        )
        let item = updated.days.first { $0.dayIndex == dayIndex }!
            .blocks.flatMap(\.items).first { $0.itemId == itemId }!
        #expect(item.sets == 1)
        #expect(item.restSec == 0)
    }

    @Test("找不到那一天或那一行时原样返回")
    func unknownTargetIsNoop() {
        let (plan, dayIndex, _) = planWithItems()
        #expect(PlanEditing.updateItem(in: plan, dayIndex: 99, itemId: "i1", sets: 5) == plan)
        #expect(PlanEditing.updateItem(in: plan, dayIndex: dayIndex, itemId: "nope", sets: 5) == plan)
    }

    @Test("估算时长随改动重算")
    func recomputesEstimatedMinutes() {
        let (plan, dayIndex, itemId) = planWithItems()
        let before = plan.days.first { $0.dayIndex == dayIndex }!.estimatedMinutes
        let updated = PlanEditing.updateItem(in: plan, dayIndex: dayIndex, itemId: itemId, sets: 8)
        let after = updated.days.first { $0.dayIndex == dayIndex }!.estimatedMinutes
        #expect(after > before)
    }
}
