import Testing
@testable import DongKeCore

@Suite("FreeTextPlanParser")
struct FreeTextPlanParserTests {
    @Test func parsesChineseSetsRepsRest() {
        let draft = FreeTextPlanParser.parse("周一\n深蹲 4组×12次，休息90秒")
        #expect(draft.plan?.days[0].blocks[0].items[0].sets == 4)
        #expect(draft.plan?.days[0].blocks[0].items[0].target.value == 12)
        #expect(draft.plan?.days[0].blocks[0].items[0].restSec == 90)
        #expect(draft.needsReview)
    }

    @Test func parsesCompactNotation() {
        let draft = FreeTextPlanParser.parse("周三 俯卧撑 3x12 休息60s")
        #expect(draft.plan?.days[2].blocks[0].items[0].sets == 3)
        #expect(draft.plan?.days[2].blocks[0].items[0].target.value == 12)
        #expect(draft.plan?.days[2].blocks[0].items[0].restSec == 60)
    }

    @Test func parsesDurationTarget() {
        let draft = FreeTextPlanParser.parse("周五 平板支撑 3组 每组30秒")
        #expect(draft.plan?.days[4].blocks[0].items[0].target.type == .durationSec)
        #expect(draft.plan?.days[4].blocks[0].items[0].target.value == 30)
    }

    @Test func parsesPerSide() {
        let draft = FreeTextPlanParser.parse("周一 弓步蹲 3组 每侧12次")
        #expect(draft.plan?.days[0].blocks[0].items[0].target.perSide == true)
    }

    @Test func parsesCircuitRounds() {
        let draft = FreeTextPlanParser.parse("周二 循环3轮\n深蹲 12次\n俯卧撑 10次")
        #expect(draft.plan?.days[1].blocks[0].kind == .circuit)
        #expect(draft.plan?.days[1].blocks[0].rounds == 3)
        #expect(draft.plan?.days[1].blocks[0].items.count == 2)
    }

    @Test func unrelatedTextReturnsBlockingIssue() {
        let draft = FreeTextPlanParser.parse("今天练一下胸吧，随便练练")
        #expect(draft.plan == nil)
        #expect(draft.hasBlockingIssues)
    }
}

@Suite("FreeTextPlanParser 标题")
struct FreeTextPlanParserTitleTests {
    @Test("全是动作行时用默认计划名，不拿动作名当标题")
    func defaultTitle() {
        let draft = FreeTextPlanParser.parse("周一 深蹲 4组×12次")
        #expect(draft.plan?.meta.title == "我的训练计划")
    }

    @Test("显式的标题行会被当作计划名")
    func customTitle() {
        let draft = FreeTextPlanParser.parse("八周增肌\n周一 深蹲 4组×12次")
        #expect(draft.plan?.meta.title == "八周增肌")
    }
}
