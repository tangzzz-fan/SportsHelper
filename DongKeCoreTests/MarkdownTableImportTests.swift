import Testing
import Foundation
@testable import DongKeCore

@Suite("Markdown 表格导入")
struct MarkdownTableImportTests {
    private func parsed(_ text: String) -> ParsedPlanDraft {
        PlanImportService.parse(text)
    }

    private func trainingDays(_ text: String) -> [(Weekday, [String])] {
        (parsed(text).plan?.days ?? [])
            .filter { !$0.isRestDay }
            .map { day in
                (day.weekday, day.blocks.flatMap(\.items).map(\.name))
            }
    }

    @Test("表头写「星期」时按天分开")
    func weekdayColumn() {
        let days = trainingDays("""
        | 星期 | 动作 | 组数 | 次数 |
        |---|---|---|---|
        | 周一 | 深蹲 | 4 | 12 |
        | 周三 | 俯卧撑 | 3 | 15 |
        """)
        #expect(days.count == 2)
        #expect(days.map { $0.0 } == [.monday, .wednesday])
        #expect(days.first?.1 == ["深蹲"])
        #expect(days.last?.1 == ["俯卧撑"])
    }

    @Test("表头写「周几」也认")
    func weekLabelColumn() {
        let days = trainingDays("""
        | 周几 | 动作 | 组数 | 次数 |
        |---|---|---|---|
        | 周二 | 卧推 | 3 | 10 |
        | 周五 | 划船 | 3 | 12 |
        """)
        #expect(days.count == 2)
        #expect(days.map { $0.0 } == [.tuesday, .friday])
    }

    @Test("英文 Day 列也认")
    func englishDayColumn() {
        let days = trainingDays("""
        | Day | Exercise | Sets | Reps |
        |---|---|---|---|
        | Monday | Squat | 4 | 12 |
        | Wednesday | Push-up | 3 | 15 |
        """)
        #expect(days.count == 2)
        #expect(days.map { $0.0 } == [.monday, .wednesday])
    }

    @Test("同一个星期出现两行会合并")
    func sameWeekdayMerges() {
        let days = trainingDays("""
        | 星期 | 动作 | 组数 | 次数 |
        |---|---|---|---|
        | 周一 | 深蹲 | 4 | 12 |
        | 周一 | 平板支撑 | 3 | 45 |
        """)
        #expect(days.count == 1)
        #expect(days.first?.1.count == 2)
    }

    @Test("表格没有星期列时仍然只排一天")
    func weeklessTableStaysOneDay() {
        let days = trainingDays("""
        | 动作 | 组数 | 次数 |
        |---|---|---|
        | 深蹲 | 4 | 12 |
        | 硬拉 | 3 | 10 |
        """)
        #expect(days.count == 1)
        #expect(days.first?.1.count == 2)
    }

    @Test("文档标题不会被当成星期名")
    func documentTitleIsNotDayLabel() {
        let draft = parsed("""
        # 一周训练计划

        | 动作 | 组数 | 次数 |
        |---|---|---|
        | 深蹲 | 4 | 12 |
        """)
        #expect(draft.plan?.meta.title == "一周训练计划")
        #expect(draft.plan?.days.first(where: { $0.weekday == .monday })?.title != "一周训练计划")
    }
}
