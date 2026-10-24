import Foundation
import Testing
@testable import DongKeCore

@Suite("语音输入：离线优先与联网同意")
@MainActor
struct VoiceInputOnlineConsentTests {
    private func machine(
        _ transcriber: FakeSpeechTranscriber,
        clock: VoiceTestClock,
        consented: Bool = false,
        recorded: @escaping @MainActor (Bool) -> Void = { _ in }
    ) -> VoiceInputMachine {
        VoiceInputMachine(
            transcribing: transcriber,
            hasConsentedToOnline: consented,
            now: { clock.now() },
            consentRecorder: recorded
        )
    }

    @Test("设备没有离线中文包：先问，不偷偷走联网")
    func asksBeforeOnline() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.supportsOnDeviceRecognition = false
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .awaitingOnlineConsent)
        #expect(transcriber.startCount == 0)
    }

    @Test("同意后走联网，并把同意记下来")
    func allowOnline() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.supportsOnDeviceRecognition = false
        let clock = VoiceTestClock()
        var recorded: [Bool] = []
        let target = machine(transcriber, clock: clock) { recorded.append($0) }
        target.start()
        await settle()
        target.allowOnline()
        await settle()

        #expect(target.phase == .listening)
        #expect(transcriber.onDeviceFlags == [false])
        #expect(recorded == [true])
        #expect(target.hasConsentedToOnline)
    }

    @Test("拒绝联网就退到键盘输入，不反复弹")
    func declineOnline() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.supportsOnDeviceRecognition = false
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()
        target.declineOnline()

        #expect(target.phase == .failed(.onDeviceUnavailable))
        #expect(transcriber.startCount == 0)
        #expect(target.hasConsentedToOnline == false)
    }

    @Test("之前同意过就不再问第二次")
    func rememberedConsentSkipsPrompt() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.supportsOnDeviceRecognition = false
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock, consented: true)

        target.start()
        await settle()

        #expect(target.phase == .listening)
        #expect(transcriber.onDeviceFlags == [false])
    }

    @Test("离线包缺失是运行时才知道的：启动报错后转成询问")
    func runtimeOnDeviceMissing() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.startError = .onDeviceUnavailable
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)

        target.start()
        await settle()

        #expect(target.phase == .awaitingOnlineConsent)
        #expect(transcriber.startCount == 1)
    }

    @Test("已同意过的话，离线失败直接改走联网，不再打断")
    func runtimeFallbackToOnline() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.startError = .onDeviceUnavailable
        transcriber.clearsStartErrorAfterThrow = true
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock, consented: true)

        target.start()
        await settle()

        #expect(target.phase == .listening)
        #expect(transcriber.onDeviceFlags == [true, false])
    }

    @Test("联网也不可用时明确说没离线包，不无限重试")
    func onlineAlsoFails() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.startError = .onDeviceUnavailable
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock, consented: true)

        target.start()
        await settle()

        #expect(target.phase == .failed(.onDeviceUnavailable))
        #expect(transcriber.startCount == 2)
    }

    @Test("在线模式中途报 offline 错误，不再回头重试")
    func onlineModeOfflineErrorEnds() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.supportsOnDeviceRecognition = false
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock, consented: true)
        target.start()
        await settle()

        transcriber.emit(.onDeviceUnavailable)

        #expect(target.phase == .failed(.onDeviceUnavailable))
        #expect(transcriber.startCount == 1)
    }

    @Test("待同意状态下点停不会误开录音")
    func stopWhileAwaitingConsent() async {
        let transcriber = FakeSpeechTranscriber()
        transcriber.supportsOnDeviceRecognition = false
        let clock = VoiceTestClock()
        let target = machine(transcriber, clock: clock)
        target.start()
        await settle()

        target.stop()

        #expect(target.phase == .awaitingOnlineConsent)
        #expect(transcriber.startCount == 0)
    }
}
