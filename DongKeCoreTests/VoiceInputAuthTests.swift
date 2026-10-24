import Foundation
import Testing
@testable import DongKeCore

@Suite("语音输入：授权与开录")
@MainActor
struct VoiceInputAuthTests {
    private func machine(
        _ transcriber: FakeSpeechTranscriber,
        clock: VoiceTestClock,
        consented: Bool = false
    ) -> VoiceInputMachine {
        VoiceInputMachine(
            transcribing: transcriber,
            hasConsentedToOnline: consented,
            now: { clock.now() }
        )
    }

    @Test("已授权时不重复弹权限，直接开录")
    func authorizedStartsImmediately() async {
        let transcriber = FakeSpeechTranscriber()
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .listening)
        #expect(transcriber.requestCount == 0)
        #expect(transcriber.startCount == 1)
        #expect(transcriber.onDeviceFlags == [true])
    }

    @Test("还没问过就先问一次，同意了才开录")
    func notDeterminedAsksOnce() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.authorization = .notDetermined
        transcriber.authorizationAfterRequest = .authorized
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(transcriber.requestCount == 1)
        #expect(target.phase == .listening)
    }

    @Test("语音识别被拒：说清原因并给去设置，不启动录音")
    func speechDenied() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.authorization = .notDetermined
        transcriber.authorizationAfterRequest = .speechDenied
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .failed(.speechDenied))
        #expect(target.phase.failure?.opensSettings == true)
        #expect(transcriber.startCount == 0)
    }

    @Test("麦克风被拒：文案指向麦克风而不是语音识别")
    func microphoneDenied() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.authorization = .microphoneDenied
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .failed(.microphoneDenied))
        #expect(target.phase.failure?.message.contains("麦克风") == true)
        #expect(transcriber.startCount == 0)
    }

    @Test("系统限制：不引导去设置页瞎点，只说明不可用")
    func restricted() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.authorization = .restricted
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .failed(.restricted))
        #expect(transcriber.startCount == 0)
    }

    @Test("没有中文识别器时给的是换输入方式，不是重试")
    func noRecognizer() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.startError = .recognizerUnavailable
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .failed(.noRecognizer))
    }

    @Test("麦克风被别的 App 占着时算中断，不是没说话")
    func audioUnavailable() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.startError = .audioUnavailable
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .failed(.interrupted))
    }

    @Test("录音中重复点麦克风不会叠出第二路录音")
    func repeatedStartIgnored() async {
        let transcriber = FakeSpeechTranscriber()
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()
        target.start()
        await settle()

        #expect(transcriber.startCount == 1)
        #expect(target.phase == .listening)
    }

    @Test("取消后回到待命，残留文字一并清掉")
    func cancelResets() async {
        let transcriber = FakeSpeechTranscriber()
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()
        transcriber.emitPartial("深蹲四组")
        target.cancel()

        #expect(target.phase == .idle)
        #expect(target.transcript.isEmpty)
        #expect(transcriber.cancelCount >= 1)
    }

    @Test("还没开录就点停，什么都不会发生")
    func stopBeforeListeningIsNoop() {
        let transcriber = FakeSpeechTranscriber()
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.stop()

        #expect(target.phase == .idle)
        #expect(transcriber.stopCount == 0)
    }
}
