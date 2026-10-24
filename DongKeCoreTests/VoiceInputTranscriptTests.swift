import Foundation
import Testing
@testable import DongKeCore

@Suite("语音输入：转写、上限与收尾")
@MainActor
struct VoiceInputTranscriptTests {
    private func listeningMachine(
        clock: VoiceTestClock
    ) async -> (VoiceInputMachine, FakeSpeechTranscriber) {
        let transcriber = FakeSpeechTranscriber()
        let target = VoiceInputMachine(
            transcribing: transcriber,
            hasConsentedToOnline: true,
            now: { clock.now() }
        )
        target.start()
        await settle()
        return (target, transcriber)
    }

    @Test("部分结果按全量替换，不做字符串累加")
    func partialReplacesInsteadOfAppends() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitPartial("想在家")
        transcriber.emitPartial("想在家增肌")
        transcriber.emitPartial("想在家增肌，每周四天")

        #expect(target.transcript == "想在家增肌，每周四天")
    }

    @Test("首尾空白不进输入框")
    func trimsWhitespace() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitPartial("   每周二四练   ")

        #expect(target.transcript == "每周二四练")
    }

    @Test("定稿就结束，phase 带上要回填的文字")
    func finalFinishes() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitFinal("每周二四，每次 45 分钟，有哑铃")

        #expect(target.phase == .finished("每周二四，每次 45 分钟，有哑铃"))
        #expect(target.phase.isListening == false)
    }

    @Test("定稿之后再来的结果一律丢弃")
    func afterFinalIgnoresMore() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitFinal("第一版")
        transcriber.emitPartial("第二版")
        transcriber.emitFinal("第三版")

        #expect(target.phase == .finished("第一版"))
        #expect(target.transcript == "第一版")
    }

    @Test("取走结果后复位，同一句话不会被回填两次")
    func consumeTakesOnce() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)
        transcriber.emitFinal("增肌")

        let taken = target.consume()

        #expect(taken == "增肌")
        #expect(target.phase == .idle)
        #expect(target.consume() == nil)
    }

    @Test("空结果给的是没听到，不是中断")
    func emptyFinal() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitFinal("")

        #expect(target.phase == .failed(.noSpeech))
    }

    @Test("只有空白也按没听到处理")
    func whitespaceFinal() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitFinal("   \n ")

        #expect(target.phase == .failed(.noSpeech))
    }

    @Test("一句话没说就点停，也是没听到")
    func stopWithoutSpeech() async {
        let clock = VoiceTestClock()
        let (target, _) = await listeningMachine(clock: clock)

        target.stop()

        #expect(target.phase == .failed(.noSpeech))
    }

    @Test("识别器报错算中断，提示重试而不是改键盘")
    func failureEvent() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)
        transcriber.emitPartial("半句话")

        transcriber.emit(.failed)

        #expect(target.phase == .failed(.interrupted))
        #expect(target.phase.failure?.opensSettings == false)
    }

    @Test("200 字截断并标记，不静默丢字")
    func overLengthTruncates() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)
        let long = String(repeating: "深", count: 250)

        transcriber.emitPartial(long)

        #expect(target.transcript.count == VoiceInputLimit.maxCharacters)
        #expect(target.didHitLengthLimit)
        #expect(target.capHint.contains("上限"))
    }

    @Test("正好 200 字不算超限")
    func exactLimitIsFine() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitPartial(String(repeating: "蹲", count: VoiceInputLimit.maxCharacters))

        #expect(target.transcript.count == VoiceInputLimit.maxCharacters)
        #expect(target.didHitLengthLimit == false)
        #expect(target.capHint == VoiceInputCopy.capHint)
    }

    @Test("识别器修正回短句后，超限提示跟着消失")
    func lengthFlagFollowsLatest() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listeningMachine(clock: clock)

        transcriber.emitPartial(String(repeating: "深", count: 250))
        transcriber.emitPartial("深蹲四组")

        #expect(target.transcript == "深蹲四组")
        #expect(target.didHitLengthLimit == false)
    }
}
