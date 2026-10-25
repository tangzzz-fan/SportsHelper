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
            renderer: speaker
        )
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(items: items)]
        ))
        let voice = WorkoutVoiceSession(plan: plan, dayIndex: 1, coordinator: coordinator)
        return (voice, speaker)
    }

    @Test("开始训练只播一次，读当天主题与动作数")
    func startSpeaksOnce() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.start()
        #expect(speaker.spoken.count == 1)
        #expect(speaker.spoken.first == "开始训练，训练，共 2 组")
    }

    @Test("进入第一组先说动作名")
    func firstSetAnnouncement() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stepChanged(to: 0)
        #expect(speaker.spoken.last == "深蹲，第 1 组，共 1 组，12 次")
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

    @Test("区块切换报下一个动作，不是区块标题")
    func blockBreakSpeaksNextAction() throws {
        let plan = makePlan(days: makeSevenDays(
            training: [1],
            blocks: [
                makeBlock(id: "b1", items: [makeItem(id: "i1", name: "开合跳", sets: 1)], restBetweenItems: 120),
                makeBlock(id: "b2", items: [makeItem(id: "i2", name: "深蹲", sets: 1)])
            ]
        ))
        let speaker = FakeSpeaker()
        let coordinator = SpeechCueCoordinator(
            policy: SpeechCuePolicy(isEnabled: true, isForeground: true, isVoiceOverRunning: false),
            renderer: speaker
        )
        let voice = WorkoutVoiceSession(plan: plan, dayIndex: 1, coordinator: coordinator)
        let breakIndex = try #require(WorkoutFlowModel(plan: plan, dayIndex: 1).steps.firstIndex {
            if case .blockBreak = $0 { true } else { false }
        })

        voice.start()
        voice.restStarted(seconds: 120, at: breakIndex)

        #expect(speaker.spoken.last == "休息，2 分钟，接下来：深蹲，12 次")
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

    @Test("休息归零只出一句：下一组自己报，休息结束不说")
    func restFinishedDefersToSetStart() {
        let (voice, speaker) = makeVoice()
        voice.start()
        voice.stepChanged(to: 0)
        let before = speaker.spoken.count
        voice.restFinished(nextStepIndex: 1)
        #expect(speaker.spoken.count == before)
    }

    @Test("没有下一组时才念休息结束")
    func restFinishedWithoutNext() {
        let (voice, speaker) = makeVoice(items: [makeItem(id: "i1", sets: 1)])
        voice.start()
        voice.restFinished(nextStepIndex: nil)
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
            "开始训练，训练，共 2 组",
            "深蹲，第 1 组，共 1 组，12 次",
            "休息，30 秒",
            "1",
            "完成 1 组，完成率 50%"
        ])
    }

    @Test("静态动作在三分之一处念要领，最后三秒报剩余，各只念一次")
    func promptsDuringHold() {
        let (voice, speaker) = makeVoice(items: [
            makeItem(id: "i1", sets: 1, value: 30, rest: 0, targetType: .durationSec)
        ])
        voice.start()
        voice.stepChanged(to: 0)
        let afterSetStart = speaker.spoken.count

        voice.setElapsed(9)
        #expect(speaker.spoken.count == afterSetStart)

        voice.setElapsed(10)
        #expect(speaker.spoken.last == ExerciseLibrary.entry(for: "squat")?.cues.first)

        voice.setElapsed(27)
        #expect(speaker.spoken.last == "3")

        let afterPrompts = speaker.spoken.count
        voice.setElapsed(28)
        voice.setElapsed(29)
        #expect(speaker.spoken.count == afterPrompts)
    }

    @Test("撑到点不再念「时间到」，归零交给提示音与触觉")
    func doesNotAnnounceTimeUp() {
        let (voice, speaker) = makeVoice(items: [
            makeItem(id: "i1", sets: 1, value: 30, rest: 0, targetType: .durationSec)
        ])
        voice.start()
        voice.stepChanged(to: 0)
        voice.setElapsed(10)
        voice.setElapsed(27)
        let before = speaker.spoken.count

        voice.setElapsed(30)
        #expect(speaker.spoken.count == before)
    }

    @Test("短组组内一句都不念")
    func shortHoldIsSilent() {
        let (voice, speaker) = makeVoice(items: [
            makeItem(id: "i1", sets: 1, value: 10, rest: 0, targetType: .durationSec)
        ])
        voice.start()
        voice.stepChanged(to: 0)
        let afterSetStart = speaker.spoken.count

        for second in 1...10 {
            voice.setElapsed(second)
        }
        #expect(speaker.spoken.count == afterSetStart)
    }

    @Test("次数型动作组内不念，免得数数打断节奏")
    func noPromptsForReps() {
        let (voice, speaker) = makeVoice(items: [makeItem(id: "i1", sets: 1, value: 12)])
        voice.start()
        voice.stepChanged(to: 0)
        let afterSetStart = speaker.spoken.count

        for second in 1...30 {
            voice.setElapsed(second)
        }
        #expect(speaker.spoken.count == afterSetStart)
    }

    @Test("换到下一组时重新排提示，不沿用上一组")
    func promptsResetPerSet() {
        let (voice, speaker) = makeVoice(items: [
            makeItem(id: "i1", sets: 2, value: 30, rest: 0, targetType: .durationSec)
        ])
        voice.start()
        voice.stepChanged(to: 0)
        voice.setElapsed(27)
        #expect(speaker.spoken.last == "3")

        let firstStep = WorkoutFlowModel(plan: makePlan(days: makeSevenDays(
            training: [1],
            blocks: [makeBlock(items: [makeItem(id: "i1", sets: 2, value: 30, rest: 0, targetType: .durationSec)])]
        )), dayIndex: 1)
        let secondSetIndex = firstStep.steps.indices.first { index in
            if case let .set(_, setIndex, _, _) = firstStep.steps[index] { setIndex == 2 } else { false }
        }
        voice.stepChanged(to: secondSetIndex ?? 1)
        let afterSecondStart = speaker.spoken.count
        voice.setElapsed(27)
        #expect(speaker.spoken.count == afterSecondStart + 1)
    }
}

@MainActor
private final class FakeSpeaker: SpeechRendering {
    private(set) var spoken: [String] = []

    var availability: SpeechAvailability { .ready }

    var profile: SpeechProfile {
        SpeechProfile(engineId: "fake", voiceName: "假引擎", charactersPerSecond: 4)
    }

    func prepare() {}

    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void) {
        spoken.append(request.text)
        event(.started(request.id))
        event(.finished(request.id, seconds: 0))
    }

    func cancel() {}
}
