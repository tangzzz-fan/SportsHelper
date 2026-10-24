import Foundation
import Testing
@testable import DongKeCore

@Suite("训练播报流程")
@MainActor
struct WorkoutVoiceSessionTests {
    private func makeVoice(
        enabled: Bool = true,
        items: [ExercisePrescription] = [makeItem(id: "i1", sets: 1), makeItem(id: "i2", name: "臀桥", sets: 1)]
    ) -> (WorkoutVoiceSession, FakeSpeaker) {
        let speaker = FakeSpeaker()
        let coordinator = SpeechCueCoordinator(
            policy: SpeechCuePolicy(isEnabled: enabled, isForeground: true, isVoiceOverRunning: false),
            announcer: speaker
        )
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(items: items)]
        ))
        let voice = WorkoutVoiceSession(plan: plan, dayIndex: 1, coordinator: coordinator)
        return (voice, speaker)
    }

    @Test("开始训练只播一次")
    func startSpeaksOnce() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.start()
        #expect(speaker.spoken.count == 1)
        #expect(speaker.spoken.first == "开始训练，测试计划，共 2 组")
    }

    @Test("进入第一组播动作与剂量")
    func firstSetAnnouncement() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stepChanged(to: 0)
        #expect(speaker.spoken.last == "第 1 组，共 1 组，深蹲，12 次，下一个：臀桥")
    }

    @Test("同一个步骤重复渲染不重播")
    func repeatedStepDoesNotRepeat() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stepChanged(to: 0)
        voice.stepChanged(to: 0)
        voice.stepChanged(to: 0)
        #expect(speaker.spoken.count == 2)
    }

    @Test("休息步骤本身不播，交给休息入口")
    func breakStepIsSilent() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stepChanged(to: 2)
        #expect(speaker.spoken.count == 1)
    }

    @Test("跳过组时不播下一组")
    func skipStaysSilent() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stepChanged(to: 0)
        voice.stepChanged(to: 1, silent: true)
        #expect(speaker.spoken.count == 2)
    }

    @Test("休息开始时报时长")
    func restStartSpeaksDuration() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.restStarted(seconds: 30)
        #expect(speaker.spoken.last == "休息，30 秒")
    }

    @Test("区块切换报下一区块名")
    func blockBreakSpeaksNextTitle() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.restStarted(seconds: 120, nextBlockTitle: "核心")
        #expect(speaker.spoken.last == "休息，2 分钟，接下来：核心")
    }

    @Test("最后 3 秒各报一次，重复 tick 不重播")
    func countdownDeduplicates() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.restStarted(seconds: 30)
        voice.restTick(secondsLeft: 3)
        voice.restTick(secondsLeft: 3)
        voice.restTick(secondsLeft: 2)
        voice.restTick(secondsLeft: 1)
        #expect(Array(speaker.spoken.suffix(3)) == ["3", "2", "1"])
        #expect(speaker.spoken.count == 5)
    }

    @Test("4 秒以上不报倒数")
    func countdownIgnoresHigherValues() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.restTick(secondsLeft: 10)
        #expect(speaker.spoken.count == 1)
    }

    @Test("+15 秒后重新从 3 开始报")
    func countdownResetsAfterExtend() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.restStarted(seconds: 20)
        voice.restTick(secondsLeft: 3)
        voice.restStarted(seconds: 35)
        voice.restTick(secondsLeft: 3)
        #expect(speaker.spoken.filter { $0 == "3" }.count == 2)
    }

    @Test("休息结束只报一次，换动作时报名字")
    func restFinishedAnnouncement() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.restFinished(nextStepIndex: 1)
        #expect(speaker.spoken.last?.contains("下一个：臀桥") == true)
    }

    @Test("下一组还是同一个动作时不报名")
    func restFinishedSameExercise() {
        let (voice, speaker) = makeVoice(items: [makeItem(id: "i1", sets: 2)])
        voice.start()
        voice.stepChanged(to: 0)
        voice.restFinished(nextStepIndex: 1)
        #expect(speaker.spoken.last == "休息结束")
    }

    @Test("完成后报完成率，之后不再播")
    func finishedThenSilent() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.finished(completedSets: 2)
        #expect(speaker.spoken.last == "完成 2 组，完成率 100%")

        voice.stepChanged(to: 0)
        #expect(speaker.spoken.count == 2)
    }

    @Test("stop 之后一句都不播")
    func stoppedStaysSilent() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stop()
        voice.stepChanged(to: 0)
        voice.restStarted(seconds: 30)
        #expect(speaker.spoken.count == 1)
    }

    @Test("开关关着时整条流程零播报")
    func disabledSessionIsSilent() {
        let (voice, speaker) = makeVoice(enabled: false)
        voice.start()
        voice.stepChanged(to: 0)
        voice.restStarted(seconds: 30)
        voice.restTick(secondsLeft: 3)
        voice.restFinished(nextStepIndex: 1)
        voice.finished(completedSets: 2)
        #expect(speaker.spoken.isEmpty)
    }

    @Test("两组完整流程的播报顺序")
    func fullSequence() {
        let (voice, speaker) = makeVoice(items: [makeItem(id: "i1", sets: 1), makeItem(id: "i2", name: "臀桥", sets: 1)])
        voice.start()
        voice.stepChanged(to: 0)
        voice.restStarted(seconds: 30)
        voice.restTick(secondsLeft: 1)
        voice.restFinished(nextStepIndex: 1)
        voice.stepChanged(to: 1, silent: true)
        voice.finished(completedSets: 1)

        #expect(speaker.spoken == [
            "开始训练，测试计划，共 2 组",
            "第 1 组，共 1 组，深蹲，12 次，下一个：臀桥",
            "休息，30 秒",
            "1",
            "休息结束，下一个：臀桥，12 次",
            "完成 1 组，完成率 50%"
        ])
    }
}

@MainActor
private final class FakeSpeaker: SpeechAnnouncing {
    private(set) var spoken: [String] = []
    private(set) var isSpeaking = false

    func speak(_ text: String) {
        spoken.append(text)
        isSpeaking = true
    }

    func stop() {
        isSpeaking = false
    }
}
