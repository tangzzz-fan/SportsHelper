import Foundation
import Testing
@testable import DongKeCore

@Suite("训练播报文案")
struct WorkoutAnnouncementTests {
    private func plan(items: [ExercisePrescription], kind: BlockKind = .main, rounds: Int = 1) -> WorkoutPlan {
        makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(kind: kind, rounds: rounds, items: items, restBetweenRounds: 60)]
        ))
    }

    private func builder(items: [ExercisePrescription]) -> WorkoutAnnouncementBuilder {
        WorkoutAnnouncementBuilder(plan: plan(items: items), dayIndex: 1)
    }

    @Test("开始训练读当天主题、动作数与总组数")
    func sessionStartReadsTitleAndSets() {
        let text = WorkoutAnnouncement.sessionStart(
            title: "居家弹力带背部", exerciseCount: 4, totalSets: 14
        ).text
        #expect(text == "开始训练，居家弹力带背部，4 个动作，共 14 组")
    }

    @Test("没有计划名时只剩动作数与总数")
    func sessionStartWithoutTitle() {
        #expect(
            WorkoutAnnouncement.sessionStart(title: "  ", exerciseCount: 3, totalSets: 9).text
                == "开始训练，3 个动作，共 9 组"
        )
    }

    @Test("休息日没有动作也没有组数时只报开始")
    func sessionStartWithoutSets() {
        #expect(
            WorkoutAnnouncement.sessionStart(title: "", exerciseCount: 0, totalSets: 0).text
                == "开始训练"
        )
    }

    @Test("每组先把动作名说出来，再报第几组")
    func setStartBasic() {
        let text = WorkoutAnnouncement.setStart(
            name: "深蹲", setIndex: 1, totalSets: 3, dose: "12 次", nextName: nil
        ).text
        #expect(text == "深蹲，第 1 组，共 3 组，12 次")
    }

    @Test("不是最后一组时带上下一个动作")
    func setStartWithNext() {
        let text = WorkoutAnnouncement.setStart(
            name: "深蹲", setIndex: 2, totalSets: 3, dose: "12 次", nextName: "臀桥"
        ).text
        #expect(text.contains("下一个：臀桥"))
    }

    @Test("四种剂量读法：次数、秒、每侧、距离")
    func doseReadings() {
        #expect(WorkoutAnnouncementBuilder.doseText(SetTarget(type: .reps, value: 12, perSide: false)) == "12 次")
        #expect(WorkoutAnnouncementBuilder.doseText(SetTarget(type: .durationSec, value: 45, perSide: false)) == "45 秒")
        #expect(WorkoutAnnouncementBuilder.doseText(SetTarget(type: .reps, value: 10, perSide: true)) == "每侧 10 次")
        #expect(WorkoutAnnouncementBuilder.doseText(SetTarget(type: .distanceM, value: 40, perSide: false)) == "40 米")
    }

    @Test("长距离换成公里，小数保留一位")
    func doseReadsKilometers() {
        #expect(WorkoutAnnouncementBuilder.doseText(SetTarget(type: .distanceM, value: 1500, perSide: false)) == "1.5 公里")
        #expect(WorkoutAnnouncementBuilder.doseText(SetTarget(type: .distanceM, value: 2000, perSide: false)) == "2 公里")
    }

    @Test("休息时长读法：秒、整分、分加秒")
    func restDurationReadings() {
        #expect(WorkoutAnnouncement.restStart(seconds: 45).text == "休息，45 秒")
        #expect(WorkoutAnnouncement.restStart(seconds: 60).text == "休息，1 分钟")
        #expect(WorkoutAnnouncement.restStart(seconds: 90).text == "休息，1 分 30 秒")
    }

    @Test("0 秒休息不播")
    func zeroRestIsSilent() {
        let builder = builder(items: [makeItem(id: "i1", rest: 0)])
        #expect(builder.restStart(seconds: 0) == nil)
    }

    @Test("倒数只报 3、2、1")
    func countdownOnlyLastThreeSeconds() {
        let builder = builder(items: [makeItem(id: "i1")])
        #expect(builder.countdown(secondsLeft: 3)?.text == "3")
        #expect(builder.countdown(secondsLeft: 2)?.text == "2")
        #expect(builder.countdown(secondsLeft: 1)?.text == "1")
    }

    @Test("4 秒与 0 秒都不报倒数")
    func countdownSkipsOtherValues() {
        let builder = builder(items: [makeItem(id: "i1")])
        #expect(builder.countdown(secondsLeft: 4) == nil)
        #expect(builder.countdown(secondsLeft: 0) == nil)
    }

    @Test("倒数被标记，方便引擎打断上一句")
    func countdownIsFlagged() {
        #expect(WorkoutAnnouncement.restCountdown(secondsLeft: 2).isCountdown)
        #expect(WorkoutAnnouncement.restStart(seconds: 30).isCountdown == false)
    }

    @Test("休息结束报下一个动作与剂量")
    func restFinishedWithNext() {
        let items = [makeItem(id: "i1"), makeItem(id: "i2", name: "臀桥")]
        let builder = builder(items: items)
        let text = builder.restFinished(nextStepIndex: 3).text
        #expect(text.contains("休息结束"))
        #expect(text.contains("下一个：臀桥"))
        #expect(text.contains("12 次"))
    }

    @Test("最后一组休息结束不编造下一个动作")
    func restFinishedWithoutNext() {
        let builder = builder(items: [makeItem(id: "i1")])
        #expect(builder.restFinished(nextStepIndex: nil).text == "休息结束")
    }

    @Test("区块切换报休息时长与下一个动作")
    func blockBreakReadsNextBlock() {
        let text = WorkoutAnnouncement.blockBreak(seconds: 120, nextLabel: "平板支撑，40 秒").text
        #expect(text == "休息，2 分钟，接下来：平板支撑，40 秒")
    }

    @Test("区块休息的「接下来」取下一个动作而不是区块标题")
    func blockBreakPrefersNextExercise() {
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [
                makeBlock(id: "b1", items: [makeItem(id: "i1", name: "开合跳", sets: 1)], restBetweenItems: 90),
                makeBlock(id: "b2", items: [makeItem(id: "i2", name: "深蹲", sets: 1)])
            ]
        ))
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)
        let breakIndex = WorkoutFlowModel(plan: plan, dayIndex: 1).steps.firstIndex {
            if case .blockBreak = $0 { true } else { false }
        }

        guard let breakIndex else {
            Issue.record("没有找到区块休息")
            return
        }
        #expect(builder.nextActionLabel(afterBlockBreakAt: breakIndex) == "深蹲，12 次")
    }

    @Test("区块切换不走 set 播报入口，由休息入口负责")
    func blockBreakIsNotASetAnnouncement() {
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [
                makeBlock(id: "b1", items: [makeItem(id: "i1", sets: 1)], restBetweenItems: 90),
                makeBlock(id: "b2", items: [makeItem(id: "i2", sets: 1)])
            ]
        ))
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)
        let breakIndex = WorkoutFlowModel(plan: plan, dayIndex: 1).steps.firstIndex {
            if case .blockBreak = $0 { true } else { false }
        }
        #expect(breakIndex != nil)
        #expect(builder.announcement(forStepAt: breakIndex!) == nil)
    }

    @Test("完成时报组数与完成率")
    func finishedReadsRate() {
        #expect(WorkoutAnnouncement.finished(completedSets: 9, plannedSets: 9).text == "完成 9 组，完成率 100%")
        #expect(WorkoutAnnouncement.finished(completedSets: 0, plannedSets: 9).text == "完成 0 组，完成率 0%")
        #expect(WorkoutAnnouncement.finished(completedSets: 5, plannedSets: 9).text.contains("56%"))
    }

    @Test("计划总组数为 0 时完成率按 0 且不出现非法百分比")
    func finishedWithoutPlan() {
        let text = WorkoutAnnouncement.finished(completedSets: 0, plannedSets: 0).text
        #expect(text == "完成 0 组，完成率 0%")
    }

    @Test("有额外组时补一句加练，完成率仍按计划组数")
    func finishedWithExtras() {
        let text = WorkoutAnnouncement.finishedWithExtras(
            completedSets: 12, plannedSets: 12, extraSets: 2
        ).text
        #expect(text.contains("完成 12 组"))
        #expect(text.contains("完成率 100%"))
        #expect(text.contains("另有 2 组加练"))
    }

    @Test("额外组为 0 时与原文案逐字一致，1 / 3 组都带加练")
    func extraAnnouncementBoundaries() {
        let builder = builder(items: [makeItem(sets: 3)])
        #expect(builder.finished(completedSets: 3).text == "完成 3 组，完成率 100%")
        #expect(builder.finished(completedSets: 3, extraSets: 1).text.contains("另有 1 组加练"))
        #expect(builder.finished(completedSets: 3, extraSets: 3).text.contains("另有 3 组加练"))
    }

    @Test("动作名很长时先丢「共 N 组」和下一个，再截断")
    func longNameDropsOptionalPartsFirst() {
        let longName = String(repeating: "侧向弓步蹲", count: 4)
        let text = WorkoutAnnouncement.setStart(
            name: longName, setIndex: 3, totalSets: 4, dose: "12 次", nextName: "臀桥"
        ).text

        #expect(text.count <= WorkoutAnnouncement.textLimit)
        #expect(text.contains("12 次"))
        #expect(text.contains("第 3 组"))
        #expect(text.contains("下一个") == false)
    }

    @Test("整份计划的每条播报都不超过 40 字")
    func everyLineFitsBudget() {
        let items = [
            makeItem(id: "i1", name: String(repeating: "保加利亚分腿蹲", count: 3)),
            makeItem(id: "i2", name: "臀桥", sets: 2),
            makeItem(id: "i3", name: "平板支撑", value: 45, targetType: .durationSec)
        ]
        let builder = builder(items: items)

        var texts: [String] = [builder.sessionStart().text]
        for index in WorkoutFlowModel(plan: plan(items: items), dayIndex: 1).steps.indices {
            if let announcement = builder.announcement(forStepAt: index) {
                texts.append(announcement.text)
            }
        }
        texts.append(builder.finished(completedSets: 8).text)

        for text in texts {
            #expect(text.count <= WorkoutAnnouncement.textLimit)
            #expect(text.isEmpty == false)
        }
    }

    @Test("最后一组不报下一个动作")
    func lastSetHasNoNext() throws {
        let builder = builder(items: [makeItem(id: "i1")])
        let flow = WorkoutFlowModel(plan: plan(items: [makeItem(id: "i1")]), dayIndex: 1)
        let lastSetIndex = try #require(flow.steps.lastIndex {
            if case .set = $0 { true } else { false }
        })

        guard case let .setStart(_, _, _, _, nextName)? = builder.announcement(forStepAt: lastSetIndex) else {
            Issue.record("最后一个 set 应产出 setStart")
            return
        }
        #expect(nextName == nil)
    }

    @Test("下一个仍是同一个动作时不重复报名")
    func sameExerciseNextIsOmitted() throws {
        let builder = builder(items: [makeItem(id: "i1", sets: 2)])
        guard case let .setStart(_, _, _, _, nextName)? = builder.announcement(forStepAt: 0) else {
            Issue.record("第一个 set 应产出 setStart")
            return
        }
        #expect(nextName == nil)
    }

    @Test("循环区块里「下一个」是本轮的下一个动作")
    func circuitNextIsWithinRound() {
        let items = [makeItem(id: "i1", name: "深蹲", sets: 1), makeItem(id: "i2", name: "划船", sets: 1)]
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(kind: .circuit, rounds: 3, items: items, restBetweenRounds: 60)]
        ))
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)

        guard case let .setStart(_, _, _, _, nextName)? = builder.announcement(forStepAt: 0) else {
            Issue.record("第一个 set 应产出 setStart")
            return
        }
        #expect(nextName == "划船")
    }

    @Test("休息日的流程里只有完成，没有 set 播报")
    func restDayAnnouncements() {
        let plan = makePlan(days: makeSevenDays(training: [], blocks: []))
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 2)

        #expect(builder.plannedSets == 0)
        #expect(builder.announcement(forStepAt: 0) == nil)
        #expect(builder.sessionStart().text == "开始训练")
    }

    @Test("循环区块的组序按动作累计，不再每轮从第 1 组重来")
    func circuitSetIndexAccumulates() {
        let items = [makeItem(id: "i1", name: "深蹲", sets: 2)]
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(kind: .circuit, rounds: 3, items: items, restBetweenRounds: 60)]
        ))
        let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)

        let indices = flow.steps.compactMap { step -> Int? in
            if case let .set(_, setIndex, _, _) = step { return setIndex }
            return nil
        }
        #expect(indices == [1, 2, 3, 4, 5, 6])
        #expect(flow.setCounts["i1"] == 6)

        guard case let .setStart(name, setIndex, totalSets, _, _)? = builder.announcement(forStepAt: 6) else {
            Issue.record("第 7 个 step 应是 set")
            return
        }
        #expect(name == "深蹲")
        #expect(setIndex == 5)
        #expect(totalSets == 6)
    }

    @Test("开始训练读当天主题，不是整份计划名")
    func sessionStartUsesDayTitle() {
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(items: [makeItem(id: "i1", sets: 2)])]
        ))
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)

        #expect(builder.sessionStart().text == "开始训练，训练，1 个动作，共 2 组")
    }
}
