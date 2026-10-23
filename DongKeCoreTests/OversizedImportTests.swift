import Foundation
import Testing
@testable import DongKeCore

@Suite("过量的粘贴")
struct OversizedImportTests {

    private func parsed(_ text: String) -> ParsedPlanDraft {
        PlanImportService.parse(text)
    }

    private func items(_ text: String) -> [ExercisePrescription] {
        (parsed(text).plan?.days ?? []).flatMap { $0.blocks.flatMap(\.items) }
    }

    private func trainingDays(_ text: String) -> [PlanDay] {
        parsed(text).plan?.days.filter { !$0.isRestDay } ?? []
    }

    @Test("四周计划只保留第 1 周，并在假设里说明")
    func fourWeeksKeepsFirst() throws {
        let text = ImportStub.text([
            ImportStub.week(1, [ImportStub.day("周一", ["深蹲 3×12"]), ImportStub.day("周三", ["臀桥 3×15"])]),
            ImportStub.week(2, [ImportStub.day("周一", ["深蹲 4×10"]), ImportStub.day("周三", ["臀桥 4×12"])]),
            ImportStub.week(3, [ImportStub.day("周一", ["深蹲 5×8"])]),
            ImportStub.week(4, [ImportStub.day("周一", ["深蹲 6×6"])])
        ])
        let draft = parsed(text)
        let plan = try #require(draft.plan)
        let days = plan.days.filter { !$0.isRestDay }
        let collected = days.flatMap(\.blocks).flatMap(\.items)

        #expect(days.count == 2)
        #expect(collected.count == 2)
        #expect(collected.map(\.target.value) == [12, 15])
        #expect(draft.assumptions.contains { $0.contains("第 1 周") })
    }

    @Test("周标题不会被当成计划名")
    func weekHeadingIsNotTitle() {
        let text = ImportStub.text([ImportStub.week(1, [ImportStub.day("周一", ["深蹲 3×12"])])])
        #expect(parsed(text).plan?.meta.title == "我的训练计划")
    }

    @Test("Day 8 以后的内容作为超出一周的部分被略去，不挤进周日")
    func daysBeyondSeven() throws {
        let text = ImportStub.text((1...10).map { "Day \($0) 深蹲 3×12" })
        let draft = parsed(text)
        let plan = try #require(draft.plan)
        let days = plan.days.filter { !$0.isRestDay }

        #expect(days.count == 7)
        #expect(days.flatMap(\.blocks).flatMap(\.items).count == 7)
        #expect(draft.assumptions.contains { $0.contains("略去") })
    }

    @Test("单日 21 个动作会被校验指出来")
    func tooManyItemsInOneDay() {
        let text = ImportStub.day("周一", ImportStub.exercises(count: 21))
        let draft = parsed(text)
        #expect(draft.hasBlockingIssues)
        #expect(draft.issues.contains { $0.message.contains("动作过多") })
    }

    @Test("单日正好 20 个动作是允许的")
    func twentyItemsInOneDay() {
        let text = ImportStub.day("周一", ImportStub.exercises(count: 20))
        let draft = parsed(text)
        #expect(draft.plan?.days.filter { !$0.isRestDay }.count == 1)
        #expect(draft.hasBlockingIssues == false)
    }

    @Test("组数越界会被校验抓住")
    func setsOutOfRange() {
        let draft = parsed("周一 深蹲 99组×999次")
        #expect(draft.issues.contains { $0.message.contains("组数") })
    }

    @Test("休息时间越界会被校验抓住")
    func restOutOfRange() {
        let draft = parsed("周一 深蹲 3×12 休息 3600秒")
        #expect(draft.issues.contains { $0.message.contains("休息") })
    }

    @Test("循环轮数越界会被校验抓住")
    func roundsOutOfRange() {
        let draft = parsed("周一 循环 50 轮\n深蹲 12次")
        #expect(draft.issues.contains { $0.message.contains("轮数") })
    }

    @Test("完全相同的动作重复 200 次只保留一次")
    func duplicateLinesCollapse() throws {
        let text = ImportStub.repeated("深蹲 3×12", times: 200)
        let draft = parsed(text)
        let plan = try #require(draft.plan)
        let collected = plan.days.flatMap(\.blocks).flatMap(\.items)

        #expect(collected.count == 1)
        #expect(draft.assumptions.contains { $0.contains("重复") })
    }

    @Test("同一行重复 400 次的超长输入也能收敛成一条")
    func oneLongLineCollapses() throws {
        let text = String(repeating: "深蹲 3×12，", count: 400)
        let plan = try #require(parsed(text).plan)
        let collected = plan.days.flatMap(\.blocks).flatMap(\.items)
        #expect(collected.count == 1)
    }

    @Test("五千行的粘贴在解析前就被挡下，而不是慢慢跑")
    func tooManyLines() {
        let text = ImportStub.repeated("深蹲 3×12", times: 5000)
        let draft = parsed(text)
        #expect(draft.plan == nil)
        #expect(draft.hasBlockingIssues)
        #expect(draft.issues.contains { $0.message.contains("内容太多") })
    }

    @Test("只粘了第 2 周时按第一周处理，不会被切空")
    func onlySecondWeek() throws {
        let text = ImportStub.text([ImportStub.week(2, [ImportStub.day("周一", ["深蹲 3×12"])])])
        let plan = try #require(parsed(text).plan)
        #expect(plan.days.filter { !$0.isRestDay }.count == 1)
    }

    @Test("多周长计划的行数只看第一周，不会被行数护栏误杀")
    func longMultiWeekPlan() throws {
        let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let weeks = (1...6).map { index in
            ImportStub.week(index, days.map { ImportStub.day($0, ImportStub.exercises(count: 14)) })
        }
        let text = ImportStub.text(weeks)
        let draft = parsed(text)
        let plan = try #require(draft.plan)

        #expect(plan.days.filter { !$0.isRestDay }.count == 7)
        #expect(draft.issues.contains { $0.message.contains("内容太多") } == false)
        #expect(draft.assumptions.contains { $0.contains("第 1 周") })
    }

    @Test("同一动作但剂量不同，不算重复")
    func differentDoseIsNotDuplicate() throws {
        let text = ImportStub.text(["周一 深蹲 3×12", "周一 深蹲 4×10"])
        let plan = try #require(parsed(text).plan)
        let items = plan.days.flatMap(\.blocks).flatMap(\.items)
        #expect(items.count == 2)
        #expect(items.map(\.sets) == [3, 4])
    }

    @Test("超过 64KB 的内容仍然先按体积挡下")
    func tooManyBytes() {
        let text = ImportStub.repeated("深蹲 3×12", times: 7000)
        let draft = parsed(text)
        #expect(draft.plan == nil)
        #expect(draft.issues.contains { $0.message.contains("64KB") })
    }
}
