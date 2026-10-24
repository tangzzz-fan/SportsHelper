import Foundation
import Testing
@testable import DongKeCore

@Suite("语音输入：60 秒上限")
@MainActor
struct VoiceInputTimeoutTests {
    private func listening(clock: VoiceTestClock) async -> (VoiceInputMachine, FakeSpeechTranscriber) {
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

    @Test("到 60 秒自动收尾，已经听到的不丢")
    func timeoutKeepsTranscript() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listening(clock: clock)
        transcriber.emitPartial("想在家增肌每周四天")

        clock.advance(60)
        target.tick()

        #expect(target.phase == .finished("想在家增肌每周四天"))
        #expect(target.remainingSeconds == 0)
    }

    @Test("到 60 秒什么都没听到，给没听到而不是空结果")
    func timeoutWithoutSpeech() async {
        let clock = VoiceTestClock()
        let (target, _) = await listening(clock: clock)

        clock.advance(61)
        target.tick()

        #expect(target.phase == .failed(.noSpeech))
    }

    @Test("没到点不收尾，剩余秒数逐秒在走")
    func remainingCountsDown() async {
        let clock = VoiceTestClock()
        let (target, _) = await listening(clock: clock)

        clock.advance(15)
        target.tick()
        #expect(target.remainingSeconds == 45)
        #expect(target.phase == .listening)

        clock.advance(30)
        target.tick()
        #expect(target.remainingSeconds == 15)
        #expect(target.phase == .listening)
    }

    @Test("超时后才到的识别结果被丢掉，不会续上")
    func lateResultDropped() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listening(clock: clock)
        transcriber.emitPartial("前半句")

        clock.advance(60)
        target.tick()
        transcriber.emitPartial("前半句后半句")

        #expect(target.phase == .finished("前半句"))
        #expect(target.transcript == "前半句")
    }

    @Test("识别器在超时前一刻还在给结果，仍按截断点收尾")
    func partialAfterDeadlineStops() async {
        let clock = VoiceTestClock()
        let (target, transcriber) = await listening(clock: clock)
        transcriber.emitPartial("开头")

        clock.advance(60)
        transcriber.emitPartial("开头加更多")

        #expect(target.phase == .finished("开头"))
    }

    @Test("每秒 tick 不会把已结束的会话叫醒")
    func tickAfterFinishIsNoop() async {
        let clock = VoiceTestClock()
        let (target, _) = await listening(clock: clock)
        target.stop()
        let settled = target.phase

        clock.advance(100)
        target.tick()

        #expect(target.phase == settled)
    }
}
