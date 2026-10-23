import Foundation
import Testing
@testable import DongKeCore

@Suite("逐行扫描：剂量写法")
struct LineScanDoseTests {

    private func items(_ text: String) -> [ExercisePrescription] {
        let plan = PlanImportService.parse(text).plan
        return (plan?.days ?? []).flatMap { $0.blocks.flatMap(\.items) }
    }

    private func first(_ text: String) -> ExercisePrescription? {
        items(text).first
    }

    @Test("全角数字按半角解析，不是丢掉剂量后套默认值")
    func fullWidthDigits() throws {
        let item = try #require(first("周一 深蹲 ４组×１２次"))
        #expect(item.sets == 4)
        #expect(item.target.value == 12)
        #expect(item.target.type == .reps)
    }

    @Test("全角数字与全角标点混用时，休息也读得出来")
    func fullWidthDigitsWithFullWidthPunctuation() throws {
        let item = try #require(first("周一 深蹲 ４组×１２次，休息９０秒"))
        #expect(item.sets == 4)
        #expect(item.restSec == 90)
    }

    @Test("中文数字写得清组数次数")
    func chineseNumerals() throws {
        let item = try #require(first("周一 深蹲 四组十二次"))
        #expect(item.sets == 4)
        #expect(item.target.value == 12)
    }

    @Test("中文数字支持「两」「十」「二十」")
    func chineseNumeralsVariants() throws {
        let pair = try #require(first("周一 深蹲 两组二十次"))
        #expect(pair.sets == 2)
        #expect(pair.target.value == 20)

        let ten = try #require(first("周一 深蹲 三组十次"))
        #expect(ten.sets == 3)
        #expect(ten.target.value == 10)
    }

    @Test("中文数字后面不是单位时不动，别把动作名改坏")
    func chineseNumeralOnlyBeforeUnits() throws {
        let item = try #require(first("周一 死虫 3组×8次"))
        #expect(item.name == "死虫")
        #expect(item.sets == 3)
    }

    @Test("小数休息按秒换算：1.5 分钟是 90 秒，不是 1 秒")
    func decimalRest() throws {
        #expect(try #require(first("周一 深蹲 3组×12次 休息1.5分钟")).restSec == 90)
        #expect(try #require(first("周一 深蹲 3组×12次 休息 0.5 分钟")).restSec == 30)
    }

    @Test("休息的单位各有各的换算")
    func restUnits() throws {
        #expect(try #require(first("周一 深蹲 3×12 休息 90s")).restSec == 90)
        #expect(try #require(first("周一 深蹲 3×12 组间休息 2 分钟")).restSec == 120)
        #expect(try #require(first("周一 深蹲 3×12 rest 75 sec")).restSec == 75)
    }

    @Test("次数在前组数在后也认")
    func reversedDose() throws {
        let item = try #require(first("周一 深蹲 12次×4组"))
        #expect(item.sets == 4)
        #expect(item.target.value == 12)
    }

    @Test("3x12 / 3*12 这类省略「组」的写法")
    func compactDose() throws {
        #expect(try #require(first("周一 深蹲 3x12")).sets == 3)
        #expect(try #require(first("周一 深蹲 3*12")).target.value == 12)
    }

    @Test("每侧写在剂量前后都算单侧")
    func perSide() throws {
        #expect(try #require(first("周一 弓步蹲 3组 每侧10次")).target.perSide)
        #expect(try #require(first("周一 弓步蹲 每侧 10 次 3 组")).sets == 3)
    }

    @Test("距离目标：公里、米、带小数的公里")
    func distanceTargets() throws {
        let km = try #require(first("周一 农夫行走 5 公里"))
        #expect(km.target.type == .distanceM)
        #expect(km.target.value == 5000)

        let half = try #require(first("周一 农夫行走 1.5 公里"))
        #expect(half.target.value == 1500)

        let meters = try #require(first("周一 农夫行走 800 米"))
        #expect(meters.target.value == 800)
    }

    @Test("时长目标：秒与分钟都换算成秒")
    func durationTargets() throws {
        let seconds = try #require(first("周一 平板支撑 45秒"))
        #expect(seconds.target.type == .durationSec)
        #expect(seconds.target.value == 45)

        let minutes = try #require(first("周一 平板支撑 2分钟"))
        #expect(minutes.target.value == 120)
    }

    @Test("重量不会被当成次数或组数，也不留在动作名里")
    func weightIsNotDose() throws {
        let item = try #require(first("周一 深蹲 5组×5次 100kg"))
        #expect(item.sets == 5)
        #expect(item.target.value == 5)
        #expect(item.name == "深蹲")
    }

    @Test("一行两个动作按别名切开，剂量各归各的")
    func twoItemsOnOneLine() throws {
        let parsed = items("周一 深蹲 3×12，臀桥 3×15")
        #expect(parsed.count == 2)
        #expect(parsed.map(\.name) == ["深蹲", "臀桥"])
        #expect(parsed.map(\.target.value) == [12, 15])
    }

    @Test("超级组只是前缀，不影响动作拆分")
    func supersetPrefix() throws {
        let parsed = items("周一 超级组：深蹲 3×12 + 臀桥 3×15")
        #expect(parsed.count == 2)
        #expect(parsed.first?.sets == 3)
    }

    @Test("省略的剂量走默认值，并且逐条写进假设")
    func defaultDoseAssumptions() throws {
        let draft = PlanImportService.parse("周一 深蹲")
        let item = try #require(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first)
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
        #expect(item.restSec == 60)
        #expect(draft.assumptions.contains { $0.contains("没写组数") })
        #expect(draft.assumptions.contains { $0.contains("没写次数") })
        #expect(draft.assumptions.contains { $0.contains("没写休息") })
    }
}

@Suite("逐行扫描：文本噪声")
struct LineScanNoiseTests {

    private func items(_ text: String) -> [ExercisePrescription] {
        let plan = PlanImportService.parse(text).plan
        return (plan?.days ?? []).flatMap { $0.blocks.flatMap(\.items) }
    }

    @Test("Markdown 勾选框不会被当成 JSON 数组")
    func markdownCheckbox() throws {
        let draft = PlanImportService.parse("- [ ] 深蹲 3×12")
        #expect(draft.path == .freeText)
        let item = try #require(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first)
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
    }

    @Test("项目符号、加粗、有序列表都能剥掉")
    func listDecoration() throws {
        #expect(items("• 深蹲 3×12").count == 1)
        #expect(items("- **深蹲** 3×12").count == 1)
        #expect(items("1. 深蹲 3×12").count == 1)
        #expect(items("1、深蹲 3×12").count == 1)
    }

    @Test("分隔线、空行、空表头都不产生动作")
    func separators() {
        let parsed = items("---\n\n   \n深蹲 3×12\n===")
        #expect(parsed.count == 1)
        #expect(parsed.first?.name == "深蹲")
    }

    @Test("注意事项进 cautions，不被当成动作")
    func cautionLines() throws {
        let draft = PlanImportService.parse("注意：膝盖不要内扣\n周一 深蹲 3×12")
        let plan = try #require(draft.plan)
        #expect(plan.cautions.contains { $0.contains("膝盖不要内扣") })
        #expect(plan.days.flatMap(\.blocks).flatMap(\.items).count == 1)
    }

    @Test("标题只做标题，不变成动作")
    func titleLine() throws {
        let draft = PlanImportService.parse("增肌计划 第一周\n周一 深蹲 3×12")
        #expect(try #require(draft.plan).meta.title == "增肌计划 第一周")
        #expect(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).count == 1)
    }

    @Test("全角括号包住的剂量照样读得出")
    func fullWidthParentheses() throws {
        let item = try #require(items("周一 深蹲（4组×12次）").first)
        #expect(item.sets == 4)
        #expect(item.target.value == 12)
    }

    @Test("多余空格与制表符不影响切分")
    func whitespaceNoise() throws {
        #expect(try #require(items("周一   深蹲    3×12").first).sets == 3)
        let tabbed = items("周一 深蹲 3×12\t周二 臀桥 3×15")
        #expect(tabbed.count == 2)
    }

    @Test("Windows 换行也能拆成两天")
    func crlf() {
        let plan = PlanImportService.parse("周一 深蹲 3×12\r\n周二 臀桥 3×15").plan
        let days = plan?.days.filter { !$0.isRestDay } ?? []
        #expect(days.count == 2)
    }

    @Test("只有动作名、库里又查不到时，整行被丢掉——当前是已知边界")
    func unknownWithoutDose() {
        let draft = PlanImportService.parse("周一 壶铃摆动")
        #expect(draft.plan == nil)
        #expect(draft.path == .blank)
    }
}
