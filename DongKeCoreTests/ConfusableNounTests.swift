import Foundation
import Testing
@testable import DongKeCore

@Suite("易混名词与单位名词")
struct ConfusableNounTests {

    private func id(_ name: String) -> String? {
        ExerciseAliasResolver.match(for: name)?.catalogId
    }

    private func firstItem(_ text: String) -> ExercisePrescription? {
        PlanImportService.parse(text).plan?.days.flatMap(\.blocks).flatMap(\.items).first
    }

    @Test("库外动作不能被硬塞进库里")
    func unknownExercisesStayUnknown() {
        let names = [
            "卧推", "杠铃卧推", "硬拉", "腿举", "引体向上", "仰卧起坐",
            "二头弯举", "侧平举", "绳索下压", "俯身飞鸟", "山羊挺身", "波比跳"
        ]
        for name in names {
            #expect(id(name) == nil, "「\(name)」不在库里，不该被认成 \(id(name) ?? "")")
        }
    }

    @Test("相近动作不能互相冒认")
    func nearMissesDoNotCollide() {
        #expect(id("靠墙深蹲") == "wall_sit", "靠墙深蹲是靠墙静蹲，不是普通深蹲")
        #expect(id("侧平板") == "side_plank", "侧平板不能被平板支撑抢走")
        #expect(id("侧身平板") == "side_plank")
        #expect(id("对侧支撑") == "bird_dog", "对侧支撑是鸟狗，不是侧平板")
        #expect(id("侧支撑") == "side_plank")
        #expect(id("半程仰卧起坐") == "crunch")
        #expect(id("仰卧起坐") == nil, "仰卧起坐与卷腹不是一回事，宁可当库外动作")
        #expect(id("提踵") == "calf_raise", "提踵不能被推举抢走")
        #expect(id("划船机") == "dumbbell_row")
        #expect(ExerciseAliasResolver.match(for: "划船机")?.modifier == "机")
    }

    @Test("剂量单位名词：次、下、个、组都算次数")
    func repUnitNouns() throws {
        for text in ["周一 深蹲 3组 12次", "周一 深蹲 3组 12下", "周一 深蹲 3组 12个"] {
            let item = try #require(firstItem(text))
            #expect(item.sets == 3, "\(text)")
            #expect(item.target.type == .reps, "\(text)")
            #expect(item.target.value == 12, "\(text)")
        }
        let english = try #require(firstItem("周一 深蹲 3 SETS x 12 REPS"))
        #expect(english.sets == 3)
        #expect(english.target.value == 12)
    }

    @Test("「个」只在写了组数时才算次数，避免把「5 个动作」当成剂量")
    func pieceUnitNeedsSets() {
        let heading = PlanImportService.parse("今天 5 个动作")
        #expect(heading.plan == nil, "只有标题的行不该被当成一组 5 个动作")
        #expect(firstItem("周一 深蹲 20个")?.target.value == 12, "没有组数时 20 个不当作次数")
    }

    @Test("时长与距离的单位名词")
    func durationAndDistanceUnits() throws {
        #expect(try #require(firstItem("周一 平板支撑 45 秒")).target.value == 45)
        #expect(try #require(firstItem("周一 平板支撑 90S")).target.value == 90)
        #expect(try #require(firstItem("周一 平板支撑 2 分钟")).target.value == 120)
        #expect(try #require(firstItem("周一 平板支撑 1 MIN")).target.value == 60)

        let km = try #require(firstItem("周一 农夫行走 5 公里"))
        #expect(km.target.type == .distanceM)
        #expect(km.target.value == 5000)
        let half = try #require(firstItem("周一 农夫行走 1.5km"))
        #expect(half.target.value == 1500)
        #expect(try #require(firstItem("周一 农夫行走 800 米")).target.value == 800)
    }

    @Test("星期名词：周、星期、礼拜、英文缩写、Day N、第 N 天")
    func weekdayNouns() {
        let cases: [(String, Weekday)] = [
            ("周一 深蹲", .monday), ("星期一 深蹲", .monday), ("礼拜一 深蹲", .monday),
            ("周天 深蹲", .sunday), ("星期日 深蹲", .sunday), ("礼拜日 深蹲", .sunday),
            ("Mon 深蹲", .monday), ("Monday 深蹲", .monday), ("Tues 深蹲", .tuesday),
            ("Thurs 深蹲", .thursday), ("Day 3 深蹲", .wednesday), ("第 5 天 深蹲", .friday)
        ]
        for (line, expected) in cases {
            #expect(DraftLineScanner.weekday(in: line) == expected, "「\(line)」应识别为 \(expected)")
        }
        #expect(DraftLineScanner.weekday(in: "第 2 周") == nil, "「第 2 周」是周标题，不是星期")
    }

    @Test("端到端：繁体、别名、单位混在一行也能落到正确动作")
    func endToEnd() throws {
        let row = try #require(firstItem("周一 啞鈴划船 3組×12次"))
        #expect(row.catalogId == "dumbbell_row")
        #expect(row.name == "哑铃划船", "繁体原文在展示时应归一成简体动作名")
        #expect(row.sets == 3)
        #expect(row.target.value == 12)

        let pushUp = try #require(firstItem("周一 掌上压 3组×10次"))
        #expect(pushUp.catalogId == "push_up")

        let lunge = try #require(firstItem("周一 剑步蹲 3组 每侧10下"))
        #expect(lunge.catalogId == "lunge")
        #expect(lunge.target.perSide)
        #expect(lunge.target.value == 10)

        let birdDog = try #require(firstItem("周一 四点支撑 3组 每侧8次"))
        #expect(birdDog.catalogId == "bird_dog")

        let jack = try #require(firstItem("周一 星星跳 3组×20个"))
        #expect(jack.catalogId == "jumping_jack")
        #expect(jack.target.value == 20)
    }
}
