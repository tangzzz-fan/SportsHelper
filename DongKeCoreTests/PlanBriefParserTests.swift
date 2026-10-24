import Testing
import Foundation
@testable import DongKeCore

@Suite("一句话计划意图")
struct PlanBriefParserTests {
    private func parse(_ text: String) -> PlanBrief {
        PlanBriefParser.parse(text)
    }

    @Test("每周天数、单次时长、器械")
    func frequencyDurationEquipment() {
        let brief = parse("每周三天，每次 30 分钟，家里有哑铃")
        #expect(brief.daysPerWeek == 3)
        #expect(brief.sessionMinutes == 30)
        #expect(brief.equipment == [.dumbbell])
        #expect(brief.weekdays == nil)
    }

    @Test("具体星期优先于笼统天数")
    func explicitWeekdays() {
        let brief = parse("周一、周三和周五练，重点手臂和核心")
        #expect(brief.weekdays == [.monday, .wednesday, .friday])
        #expect(brief.daysPerWeek == nil)
        #expect(brief.focus == ["手臂", "核心"])
    }

    @Test("一三五这种连写也认")
    func compactWeekdayRun() {
        #expect(parse("一三五练").weekdays == [.monday, .wednesday, .friday])
        #expect(parse("每周一三五").weekdays == [.monday, .wednesday, .friday])
    }

    @Test("周末是周六加周日")
    func weekend() {
        #expect(parse("周末练两次").weekdays == [.saturday, .sunday])
    }

    @Test("每周三练是频率，不是星期三")
    func weeklyThreeTimesIsNotWednesday() {
        let brief = parse("每周三练")
        #expect(brief.weekdays == nil)
        #expect(brief.daysPerWeek == 3)
    }

    @Test("每周三才是星期三")
    func weeklyWednesday() {
        let brief = parse("每周三，每次 30 分钟")
        #expect(brief.weekdays == [.wednesday])
        #expect(brief.daysPerWeek == nil)
    }

    @Test("每周一三五练仍是三个具体星期")
    func weeklyCompactedWeekdaysWithVerb() {
        let brief = parse("每周一三五练")
        #expect(brief.weekdays == [.monday, .wednesday, .friday])
        #expect(brief.daysPerWeek == nil)
    }

    @Test("每天与天天都是七天")
    func everyDay() {
        #expect(parse("每天练").daysPerWeek == 7)
        #expect(parse("天天练").daysPerWeek == 7)
    }

    @Test("一周三练、我想练三天都算频率")
    func frequencyPhrases() {
        #expect(parse("一周三练").daysPerWeek == 3)
        #expect(parse("我想练三天").daysPerWeek == 3)
        #expect(parse("三天，每次半小时").daysPerWeek == 3)
    }

    @Test("休息三天不是训练频率")
    func restDaysAreNotFrequency() {
        #expect(parse("休息三天").daysPerWeek == nil)
    }

    @Test("隔天不硬换算成星期")
    func everyOtherDay() {
        let brief = parse("隔天练，每次 30 分钟")
        #expect(brief.daysPerWeek == nil)
        #expect(brief.weekdays == nil)
        #expect(brief.unparsed.contains { $0.contains("隔天") })
    }

    @Test("半小时、一个半小时、1.5 小时")
    func durationPhrases() {
        #expect(parse("每次半小时").sessionMinutes == 30)
        #expect(parse("每次一个半小时").sessionMinutes == 90)
        #expect(parse("每次 1.5 小时").sessionMinutes == 90)
        #expect(parse("每次一小时").sessionMinutes == 60)
    }

    @Test("时长区间取上限，装得下比装不满安全")
    func durationRange() {
        #expect(parse("每次 20-30 分钟").sessionMinutes == 30)
    }

    @Test("目标词各归各的")
    func goals() {
        #expect(parse("想减脂").goal == .loseFat)
        #expect(parse("想增肌").goal == .buildMuscle)
        #expect(parse("练耐力").goal == .endurance)
        #expect(parse("提高体能").goal == .generalFitness)
        #expect(parse("想拉伸放松").goal == .mobility)
    }

    @Test("器械可以多个，顺序稳定")
    func equipmentList() {
        let brief = parse("有哑铃、弹力带和卧凳")
        #expect(brief.equipment == [.dumbbell, .band, .bench])
    }

    @Test("徒手与没器械都落到 bodyweight")
    func bodyweight() {
        #expect(parse("徒手练").equipment == [.bodyweight])
        #expect(parse("家里没器械").equipment == [.bodyweight])
        #expect(parse("不想去健身房").equipment == [.bodyweight])
    }

    @Test("重点部位去重且保持出现顺序")
    func focusParts() {
        #expect(parse("重点练臀腿，也带一点核心和臀").focus == ["臀部", "腿部", "核心"])
        #expect(parse("胸背腿").focus == ["胸部", "背部", "腿部"])
    }

    @Test("不要、别、避免后面的动作进避开清单")
    func avoidActions() {
        #expect(parse("不要跳跃动作").avoid.contains("跳跃"))
        #expect(parse("别做深蹲").avoid.contains("深蹲"))
        #expect(parse("避免弓步").avoid.contains("弓步"))
    }

    @Test("疼痛部位原样记下")
    func painPhrases() {
        let brief = parse("膝盖不好，腰也疼")
        #expect(brief.avoid.contains { $0.contains("膝盖") })
        #expect(brief.avoid.contains { $0.contains("腰") })
    }

    @Test("随便你定是空意图，不是零值意图")
    func vague() {
        let brief = parse("随便，你定")
        #expect(brief.isVague)
        #expect(brief.daysPerWeek == nil)
        #expect(brief.sessionMinutes == nil)
        #expect(brief.equipment == nil)
        #expect(brief.goal == nil)
    }

    @Test("空输入是空意图")
    func empty() {
        let brief = parse("   ")
        #expect(brief.sentence.isEmpty)
        #expect(brief.isVague)
    }

    @Test("超出范围的天数不静默截断")
    func outOfRangeDays() {
        let brief = parse("每周八天")
        #expect(brief.daysPerWeek == nil)
        #expect(brief.unparsed.contains { $0.contains("8") })
    }

    @Test("太短与太长的单次时长都不收")
    func outOfRangeDuration() {
        #expect(parse("每次 3 分钟").sessionMinutes == nil)
        #expect(parse("每次 180 分钟").sessionMinutes == nil)
        #expect(parse("每次 3 分钟").unparsed.isEmpty == false)
    }

    @Test("杠铃不在选项里就明说，不偷换成哑铃")
    func unsupportedEquipment() {
        let brief = parse("只有杠铃")
        #expect(brief.equipment == nil)
        #expect(brief.unparsed.contains { $0.contains("杠铃") })
    }

    @Test("繁体动作词与单位也能归一")
    func traditionalChinese() {
        let brief = parse("每週三天，有啞鈴，練手臂")
        #expect(brief.daysPerWeek == 3)
        #expect(brief.equipment == [.dumbbell])
        #expect(brief.focus == ["手臂"])
    }

    @Test("全角数字不进 unparsed")
    func fullWidthDigits() {
        let brief = parse("３天，３０分钟")
        #expect(brief.daysPerWeek == 3)
        #expect(brief.sessionMinutes == 30)
        #expect(brief.unparsed.isEmpty)
    }

    @Test("混合长句只取认识的，剩下不硬猜")
    func mixedSentence() {
        let brief = parse("我想在家增肌，每周四天，每次 40 分钟，有哑铃和弹力带，重点练背和肩，膝盖不好别跳")
        #expect(brief.goal == .buildMuscle)
        #expect(brief.daysPerWeek == 4)
        #expect(brief.sessionMinutes == 40)
        #expect(brief.equipment == [.dumbbell, .band])
        #expect(brief.focus == ["背部", "肩部"])
        #expect(brief.avoid.contains { $0.contains("膝盖") })
        #expect(brief.avoid.contains("跳跃"))
    }

    @Test("原话保留，截断到 200 字")
    func sentenceIsKept() {
        let long = String(repeating: "练", count: 260)
        let brief = parse(long)
        #expect(brief.sentence.count == 200)
    }

    @Test("没有说话时也能分辨哪些字段来自句子")
    func overriddenFields() {
        let brief = parse("每周三天，有哑铃")
        #expect(brief.overriddenFields == [.weekdays, .equipment])
        #expect(parse("重点手臂").overriddenFields == [.focus])
    }
}

@Suite("一句话意图与档案合并")
struct PlanBriefResolutionTests {
    private var profile: UserProfile {
        var profile = UserProfile()
        profile.goal = .loseFat
        profile.availableWeekdays = [.monday, .wednesday, .friday]
        profile.sessionMinutes = 30
        profile.equipment = [.dumbbell]
        profile.injuries = "左膝不适"
        return profile
    }

    @Test("没说的字段沿用档案")
    func fallsBackToProfile() {
        let effective = PlanBriefParser.parse("重点手臂").resolved(against: profile)
        #expect(effective.weekdays == [.monday, .wednesday, .friday])
        #expect(effective.sessionMinutes == 30)
        #expect(effective.equipment == [.dumbbell])
        #expect(effective.goal == .loseFat)
        #expect(effective.focus == ["手臂"])
    }

    @Test("具体星期与笼统天数冲突时以星期为准")
    func weekdaysBeatCount() {
        let brief = parseBrief(weekdays: [.monday, .wednesday], daysPerWeek: 5)
        #expect(brief.resolved(against: profile).weekdays == [.monday, .wednesday])
    }

    @Test("只给天数时按档案的星期补齐")
    func fillsMissingWeekdays() {
        let effective = PlanBriefParser.parse("每周四天").resolved(against: profile)
        #expect(effective.weekdays.count == 4)
        #expect(effective.weekdays.contains(.monday))
        #expect(effective.weekdays.contains(.wednesday))
        #expect(effective.weekdays.contains(.friday))
    }

    @Test("句子覆盖时长、器械、目标，但不改伤病")
    func overridesButKeepsInjuries() {
        let effective = PlanBriefParser.parse("每周三天，每次 45 分钟，只有弹力带，想增肌").resolved(against: profile)
        #expect(effective.sessionMinutes == 45)
        #expect(effective.equipment == [.band])
        #expect(effective.goal == .buildMuscle)
        #expect(effective.injuries == "左膝不适")
        #expect(effective.avoid.isEmpty == false || effective.injuries.isEmpty == false)
    }

    @Test("动作与组数上限跟着本次时长走")
    func capsFollowSessionMinutes() {
        let short = PlanBriefParser.parse("每次 20 分钟").resolved(against: profile)
        #expect(short.maxExercises == 4)
        #expect(short.maxSets == 10)

        let long = PlanBriefParser.parse("每次 60 分钟").resolved(against: profile)
        #expect(long.maxExercises == 8)
        #expect(long.maxSets == 30)
    }

    @Test("档案星期为空也有兜底")
    func emptyProfileWeekdays() {
        var empty = profile
        empty.availableWeekdays = []
        let effective = PlanBriefParser.parse("每周三天").resolved(against: empty)
        #expect(effective.weekdays.count == 3)
    }

    @Test("保险：天数只接受 1 到 7")
    func clampsDays() {
        let brief = parseBrief(daysPerWeek: 9)
        #expect(brief.resolved(against: profile).weekdays.count == 7)
    }

    private func parseBrief(weekdays: [Weekday]? = nil, daysPerWeek: Int? = nil) -> PlanBrief {
        PlanBrief(sentence: "测试", weekdays: weekdays, daysPerWeek: daysPerWeek)
    }
}
