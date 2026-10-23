import Foundation
import Testing
@testable import DongKeCore

@Suite("不完整的粘贴")
struct IncompleteImportTests {

    private func parsed(_ text: String) -> ParsedPlanDraft {
        PlanImportService.parse(text)
    }

    private func items(_ text: String) -> [ExercisePrescription] {
        (parsed(text).plan?.days ?? []).flatMap { $0.blocks.flatMap(\.items) }
    }

    private func trainingDays(_ text: String) -> [PlanDay] {
        parsed(text).plan?.days.filter { !$0.isRestDay } ?? []
    }

    @Test("末尾悬空一个没有动作的星期，不影响前面的内容")
    func danglingWeekday() {
        let text = ImportStub.text(["周一", "深蹲 3×12", "周二"])
        let days = trainingDays(text)
        #expect(days.count == 1)
        #expect(days.flatMap(\.blocks).flatMap(\.items).count == 1)
        #expect(parsed(text).hasBlockingIssues == false)
    }

    @Test("只写了一个星期，什么都没练")
    func weekdayOnly() {
        let draft = parsed("周一")
        #expect(draft.plan == nil)
        #expect(draft.path == .blank)
        #expect(draft.issues.contains { $0.message.contains("未能") })
    }

    @Test("只有标题没有动作")
    func titleOnly() {
        #expect(parsed("增肌计划 第一周").plan == nil)
    }

    @Test("只有注意事项没有动作")
    func cautionOnly() {
        #expect(parsed("注意：膝盖痛就别练").plan == nil)
    }

    @Test("只剩分隔线与空行")
    func separatorsOnly() {
        #expect(parsed("---\n\n===\n\n").plan == nil)
    }

    @Test("组数写全了，乘号后面没写次数")
    func trailingMultiplication() throws {
        let item = try #require(items("周一 深蹲 3组×").first)
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
    }

    @Test("只有次数，组数没写")
    func leadingMultiplication() throws {
        let item = try #require(items("周一 深蹲 ×12次").first)
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
    }

    @Test("休息只写了词，没有数字")
    func restWithoutNumber() throws {
        let text = "周一 深蹲 3×12 休息"
        let draft = parsed(text)
        #expect(try #require(items(text).first).restSec == 60)
        #expect(draft.assumptions.contains { $0.contains("没写休息") })
    }

    @Test("最后一行停在半个词上，前面的照常解析")
    func halfWrittenLastLine() {
        let text = ImportStub.text(["周一 深蹲 3×12", "周二 臀桥 3×15 休"])
        let days = trainingDays(text)
        #expect(days.count == 2)
        #expect(days.last?.blocks.first?.items.first?.restSec == 60)
    }

    @Test("代码围栏里的 JSON 被截断时明确说「没粘完整」")
    func truncatedFencedJSON() {
        let text = "```json\n{\"days\":[{\"day\":\"周一\",\"items\":[{\"name\":\"深蹲\""
        let draft = parsed(text)
        #expect(draft.plan == nil)
        #expect(draft.hasBlockingIssues)
        #expect(draft.issues.contains { $0.message.contains("没粘完整") })
    }

    @Test("裸 JSON 少一个右括号同样报「没粘完整」")
    func truncatedBareJSON() {
        let text = #"{"days":[{"day":"周一","items":[{"name":"深蹲"}]}]"#
        let draft = parsed(text)
        #expect(draft.plan == nil)
        #expect(draft.issues.contains { $0.message.contains("没粘完整") })
    }

    @Test("JSON 里某一天只有标题没有动作")
    func jsonDayWithoutItems() {
        let text = ImportStub.rawJSON(["days": [["day": "周一"]]])
        let draft = parsed(text)
        #expect(draft.plan == nil)
        #expect(draft.hasBlockingIssues)
    }

    @Test("days 写成对象而不是数组")
    func daysAsObject() {
        let text = ImportStub.rawJSON(["days": ["day": "周一"]])
        let draft = parsed(text)
        #expect(draft.plan == nil)
        #expect(draft.hasBlockingIssues)
    }

    @Test("围栏里其实是纯文本时，按自由文本解析而不是报 JSON 错")
    func fencedPlainText() throws {
        let text = "```\n周一 深蹲 3×12\n```"
        let draft = parsed(text)
        #expect(draft.path == .freeText)
        let plan = try #require(draft.plan)
        #expect(plan.days.flatMap(\.blocks).flatMap(\.items).count == 1)
    }

    @Test("JSON 顶层的 days 是空数组")
    func emptyDaysArray() {
        let text = ImportStub.rawJSON(["days": [String]()])
        #expect(parsed(text).plan == nil)
    }
}
