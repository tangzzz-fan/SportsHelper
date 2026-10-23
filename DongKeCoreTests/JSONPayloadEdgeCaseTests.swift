import Foundation
import Testing
@testable import DongKeCore

@Suite("JSON 载荷：形状与脏格式")
struct JSONPayloadEdgeCaseTests {

    private func parsed(_ text: String) -> ParsedPlanDraft {
        PlanImportService.parse(text)
    }

    private func items(_ text: String) -> [ExercisePrescription] {
        (parsed(text).plan?.days ?? []).flatMap { $0.blocks.flatMap(\.items) }
    }

    private let generic = #"{"days":[{"day":"周一","items":[{"name":"深蹲","sets":3,"reps":12}]}]}"#

    @Test("代码围栏包住的通用 JSON 也要能解析")
    func fencedGenericJSON() throws {
        let text = "这是计划：\n```json\n\(generic)\n```\n加油"
        let draft = parsed(text)
        #expect(draft.path == .lenientJSON)
        let item = try #require(items(text).first)
        #expect(item.name == "深蹲")
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
    }

    @Test("前后夹着说明文字的 JSON 同样能解析")
    func proseWrappedJSON() {
        #expect(items("按这个练：\(generic) 有问题再问我").count == 1)
    }

    @Test("顶层是「每天一个对象」的数组")
    func rootArrayOfDays() {
        let text = #"[{"day":"周一","items":[{"name":"深蹲","sets":4,"reps":10}]},{"day":"周三","items":[{"name":"臀桥","sets":3,"reps":15}]}]"#
        let plan = parsed(text).plan
        let days = plan?.days.filter { !$0.isRestDay } ?? []
        #expect(days.count == 2)
        #expect(days.flatMap(\.blocks).flatMap(\.items).count == 2)
    }

    @Test("weeks → days 再套一层也能穿进去")
    func weeksNested() {
        let text = #"{"weeks":[{"days":[{"day":"周二","items":[{"name":"开合跳","sets":3,"reps":30}]}]}]}"#
        #expect(items(text).count == 1)
    }

    @Test("尾随逗号不挡路")
    func trailingComma() {
        let text = #"{"days":[{"day":"周一","items":[{"name":"深蹲","sets":3,"reps":12},]}]}"#
        #expect(items(text).count == 1)
    }

    @Test("数字写成字符串、次数是区间，都按第一档算并写进假设")
    func stringNumbersAndRange() throws {
        let text = #"{"days":[{"day":"周一","items":[{"name":"深蹲","sets":"3","reps":"8-12"}]}]}"#
        let draft = parsed(text)
        let item = try #require(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first)
        #expect(item.sets == 3)
        #expect(item.target.value == 8)
        #expect(draft.assumptions.contains { $0.contains("8-12") })
    }

    @Test("reps 为 null 时退到 duration")
    func nullRepsUsesDuration() throws {
        let text = #"{"days":[{"day":"周一","items":[{"name":"平板支撑","sets":3,"reps":null,"duration":30}]}]}"#
        let item = try #require(items(text).first)
        #expect(item.target.type == .durationSec)
        #expect(item.target.value == 30)
    }

    @Test("中文字段名的计划也认")
    func chineseKeys() throws {
        let text = #"{"训练日":[{"星期":"周一","动作":[{"动作名":"深蹲","组数":3,"次数":12,"休息":90}]}]}"#
        let item = try #require(items(text).first)
        #expect(item.name == "深蹲")
        #expect(item.sets == 3)
        #expect(item.restSec == 90)
    }

    @Test("契约 JSON 缺 restSec 时补 60 秒并给出带路径的提醒")
    func missingRestWarns() {
        let draft = parsed(validPlanJSON(includeRest: false))
        #expect(draft.plan?.days.flatMap(\.blocks).flatMap(\.items).first?.restSec == 60)
        #expect(draft.issues.contains { $0.path.contains("restSec") && $0.severity == .warning })
    }

    @Test("通用 JSON 不带 restSec 时静默补 60 秒")
    func missingRestInGenericJSON() {
        #expect(items(generic).first?.restSec == 60)
    }

    @Test("完整契约但只有三天时，校验会指出「一周必须有 7 天」")
    func threeDaysIsInvalid() throws {
        var root = try #require(
            try JSONSerialization.jsonObject(with: Data(validPlanJSON().utf8)) as? [String: Any]
        )
        let days = try #require(root["days"] as? [Any])
        root["days"] = Array(days.prefix(3))
        let data = try JSONSerialization.data(withJSONObject: root)
        let draft = parsed(String(decoding: data, as: UTF8.self))

        #expect(draft.plan != nil)
        #expect(draft.hasBlockingIssues)
        #expect(draft.issues.contains { $0.message.contains("7 天") })
    }

    @Test("只写了三天的通用 JSON 会被补成七天骨架，不报错")
    func threeGenericDaysArePadded() {
        let text = #"{"days":[{"day":"周一","items":[{"name":"深蹲","sets":3,"reps":12}]},{"day":"周三","items":[{"name":"臀桥","sets":3,"reps":15}]},{"day":"周五","items":[{"name":"开合跳","sets":3,"reps":30}]}]}"#
        let draft = parsed(text)
        let days = draft.plan?.days.filter { !$0.isRestDay } ?? []
        #expect(draft.plan?.days.count == 7)
        #expect(days.count == 3)
        #expect(draft.hasBlockingIssues == false)
    }

    @Test("空数组不再被当成 JSON：交给自由文本，报「未能识别」")
    func emptyBracketsFallsBackToText() {
        let draft = parsed("[]")
        #expect(draft.plan == nil)
        #expect(draft.issues.contains { $0.message.contains("未能") })
    }

    @Test("空对象与空 days 给出结构错误，不是系统错误")
    func emptyContainers() {
        for text in [#"{}"#, #"{"days":[]}"#] {
            let draft = parsed(text)
            #expect(draft.plan == nil)
            #expect(draft.path == .lenientJSON)
            #expect(draft.hasBlockingIssues)
        }
    }

    @Test("全角引号包的 JSON 先清洗再解码")
    func curlyQuotes() throws {
        let text = "{\u{201C}days\u{201D}:[{\u{201C}day\u{201D}:\u{201C}周一\u{201D},\u{201C}items\u{201D}:[{\u{201C}name\u{201D}:\u{201C}深蹲\u{201D},\u{201C}sets\u{201D}:3,\u{201C}reps\u{201D}:12}]}]}"
        let item = try #require(items(text).first)
        #expect(item.sets == 3)
        #expect(item.target.value == 12)
    }

    @Test("键值之间的全角冒号、全角逗号也能清洗")
    func fullWidthPunctuation() throws {
        let text = "{\"days\":[{\"day\":\"周一\",\"items\":[{\"name\":\"深蹲\",\"sets\"：3,\"reps\":12}]}]}"
        #expect(try #require(items(text).first).sets == 3)
    }

    @Test("带 BOM 的 JSON 能读")
    func byteOrderMark() {
        #expect(items("\u{FEFF}\(generic)").count == 1)
    }

    @Test("组数为 0 会被校验抓住，而不是静默变成默认值")
    func zeroSetsIsRejected() {
        let text = #"{"days":[{"day":"周一","items":[{"name":"深蹲","sets":0,"reps":12}]}]}"#
        let draft = parsed(text)
        #expect(draft.hasBlockingIssues)
        #expect(draft.issues.contains { $0.message.contains("组数") })
    }

    @Test("围栏里的完整契约 JSON 直接走严格解码")
    func fencedStrictSchema() {
        let fenced = "```json\n\(validPlanJSON())\n```"
        #expect(parsed(fenced).path == .strictJSON)
    }
}
