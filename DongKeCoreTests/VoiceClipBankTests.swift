import Testing
@testable import DongKeCore

@Suite("音条切分")
struct VoiceClipBankTests {
    @Test("组开始切成四段")
    func setStartSplits() {
        let plan = VoiceClipBank.plan(for: "俯卧撑，第 1 组，共 3 组，10 次")
        #expect(plan == .clips(["俯卧撑", "第 1 组", "共 3 组", "10 次"]))
    }

    @Test("休息切成两段")
    func restSplits() {
        #expect(VoiceClipBank.plan(for: "休息，30 秒") == .clips(["休息", "30 秒"]))
    }

    @Test("跨区块休息按冒号再切，长时长拆成分与秒")
    func blockBreakSplits() {
        let plan = VoiceClipBank.plan(for: "休息，1 分 30 秒，接下来：平板支撑，40 秒")
        #expect(plan == .clips(["休息", "1 分", "30 秒", "接下来", "平板支撑", "40 秒"]))
    }

    @Test("完成句含百分比也能切")
    func finishedSplits() {
        #expect(VoiceClipBank.plan(for: "完成 9 组，完成率 100%") == .clips(["完成 9 组", "完成率 100%"]))
    }

    @Test("倒数就是一个数字")
    func countdownDigit() {
        #expect(VoiceClipBank.plan(for: "3") == .clips(["3"]))
    }

    @Test("开场句不含主题名之后能切；带主题名就必然回落")
    func sessionStartSplitOnlyWithoutTitle() {
        #expect(VoiceClipBank.plan(for: "开始训练，共 9 组，3 个动作") == .clips(["开始训练", "共 9 组", "3 个动作"]))
        // 这是它被去掉的原因：主题名是 AI 生成的，录不了。
        #expect(VoiceClipBank.plan(for: "开始训练，上肢与核心") == .fallback)
    }

    @Test("整节课每一条播报都能切成音条，不需要回落系统 TTS")
    func fullSessionIsFullyCovered() {
        let blocks = [
            makeBlock(
                kind: .circuit,
                rounds: 2,
                items: [
                    makeItem(id: "i1", name: "深蹲", sets: 2),
                    makeItem(id: "i2", name: "平板支撑", sets: 2, value: 40, targetType: .durationSec)
                ],
                restBetweenItems: 30,
                restBetweenRounds: 60
            ),
            makeBlock(
                id: "b2",
                items: [makeItem(id: "i3", name: "臀桥", sets: 3, value: 15)],
                restBetweenItems: 90
            )
        ]
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: blocks))
        let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)
        let steps = WorkoutFlowModel(plan: plan, dayIndex: 1).steps

        var texts: [String] = [builder.sessionStart().text]
        for index in steps.indices {
            switch steps[index] {
            case .set:
                if let announcement = builder.announcement(forStepAt: index) {
                    texts.append(announcement.text)
                }
                for prompt in builder.prompts(at: index) {
                    texts.append(WorkoutAnnouncement.setPrompt(prompt.prompt).text)
                }
            case let .roundBreak(seconds):
                if let announcement = builder.restStart(seconds: seconds) {
                    texts.append(announcement.text)
                }
            case let .blockBreak(seconds, _):
                texts.append(
                    WorkoutAnnouncement.blockBreak(
                        seconds: seconds,
                        nextLabel: builder.nextActionLabel(afterBlockBreakAt: index) ?? ""
                    ).text
                )
            case .finished:
                texts.append(builder.finished(completedSets: 5).text)
                texts.append(builder.finished(completedSets: 5, extraSets: 2).text)
            }
        }
        for left in [3, 2, 1] {
            if let announcement = builder.countdown(secondsLeft: left) {
                texts.append(announcement.text)
            }
        }
        if let announcement = builder.restFinished(nextStepIndex: steps.indices.first {
            if case .set = steps[$0] { true } else { false }
        }) {
            texts.append(announcement.text)
        }

        #expect(texts.count > 10)
        for text in texts {
            if case .fallback = VoiceClipBank.plan(for: text) {
                Issue.record("这句会回落系统 TTS：\(text)")
            }
        }
    }

    @Test("动作库的每条要点都有音条")
    func everyCueIsRecorded() {
        for entry in ExerciseLibrary.all {
            for cue in entry.cues {
                #expect(VoiceClipBank.contains(cue), "缺要点音条：\(cue)")
            }
        }
    }

    @Test("要点句不超过 24 字，读出来不到 6 秒")
    func cueLengthIsBounded() {
        // .focus 不走 compose 的预算，长度只能靠内容自己守。实测 4.0–4.3 字/秒。
        for entry in ExerciseLibrary.all {
            for cue in entry.cues {
                #expect(cue.count <= 24, "要点太长：\(cue)")
            }
        }
    }

    @Test("超范围的组数回退")
    func outOfRangeFallsBack() {
        #expect(VoiceClipBank.plan(for: "俯卧撑，第 99 组，共 3 组，10 次") == .fallback)
    }

    @Test("自由文本回退")
    func freeTextFallsBack() {
        #expect(VoiceClipBank.plan(for: "小腹收紧，肋骨别外翻") == .fallback)
    }

    @Test("空串回退")
    func emptyFallsBack() {
        #expect(VoiceClipBank.plan(for: "   ") == .fallback)
    }

    @Test("片段 id 稳定且互不相同")
    func clipIdsAreStable() {
        let a = VoiceClipBank.clipId(for: "俯卧撑")
        #expect(a == VoiceClipBank.clipId(for: "俯卧撑"))
        #expect(a != VoiceClipBank.clipId(for: "臀桥"))
        #expect(a.count == 16)
    }

    @Test("动作库里的名字都能切出来")
    func everyExerciseNameIsCovered() {
        for entry in ExerciseLibrary.all {
            #expect(VoiceClipBank.contains(entry.name), "\(entry.name) 不在音条库里")
        }
    }

    @Test("清单里没有重复项")
    func inventoryHasNoDuplicates() {
        #expect(Set(VoiceClipBank.inventory).count == VoiceClipBank.inventory.count)
    }
}
