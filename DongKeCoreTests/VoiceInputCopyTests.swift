import Foundation
import Testing
@testable import DongKeCore

@Suite("语音输入：文案")
struct VoiceInputCopyTests {
    @Test("每个失败原因都有具体说法，不是「出错了」")
    func everyFailureHasMessage() {
        for failure in VoiceInputFailure.allCases {
            #expect(failure.message.isEmpty == false)
            #expect(failure.message.contains("出错了") == false)
            #expect(failure.message.contains("未知") == false)
        }
    }

    @Test("只有权限类失败才引导去设置")
    func onlyPermissionFailuresOpenSettings() {
        let settings: [VoiceInputFailure] = [.speechDenied, .microphoneDenied, .restricted]
        for failure in VoiceInputFailure.allCases {
            #expect(failure.opensSettings == settings.contains(failure))
        }
    }

    @Test("没听到和中断要分开，前者让人重说，后者让人重试")
    func noSpeechIsNotInterrupted() {
        #expect(VoiceInputFailure.noSpeech.message != VoiceInputFailure.interrupted.message)
        #expect(VoiceInputFailure.noSpeech.opensSettings == false)
    }

    @Test("隐私文案说清不存录音")
    func privacySaysNoAudio() {
        #expect(VoiceInputCopy.privacy.contains("不保存录音"))
        #expect(VoiceInputCopy.onlineBody.contains("Apple"))
        #expect(VoiceInputCopy.onlineBody.contains("不保存音频"))
    }

    @Test("上限提示写明秒数与字数")
    func capHintStatesBothLimits() {
        #expect(VoiceInputCopy.capHint.contains("60"))
        #expect(VoiceInputCopy.capHint.contains("200"))
    }
}
