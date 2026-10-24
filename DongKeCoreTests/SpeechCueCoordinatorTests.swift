import Foundation
import Testing
@testable import DongKeCore

@Suite("播报闸门与插话")
@MainActor
struct SpeechCueCoordinatorTests {
    private func coordinator(
        enabled: Bool = true,
        foreground: Bool = true,
        voiceOver: Bool = false
    ) -> (SpeechCueCoordinator, FakeAnnouncer) {
        let announcer = FakeAnnouncer()
        let coordinator = SpeechCueCoordinator(
            policy: SpeechCuePolicy(
                isEnabled: enabled,
                isForeground: foreground,
                isVoiceOverRunning: voiceOver
            ),
            announcer: announcer
        )
        return (coordinator, announcer)
    }

    @Test("开关关着时一句都不念")
    func disabledStaysSilent() {
        let (coordinator, announcer) = coordinator(enabled: false)
        coordinator.announce(.restStart(seconds: 30))
        #expect(announcer.spoken.isEmpty)
        #expect(coordinator.lastSpokenText == nil)
    }

    @Test("App 在后台时不念")
    func backgroundStaysSilent() {
        let (coordinator, announcer) = coordinator(foreground: false)
        coordinator.announce(.restStart(seconds: 30))
        #expect(announcer.spoken.isEmpty)
    }

    @Test("VoiceOver 开着时让路")
    func voiceOverYields() {
        let (coordinator, announcer) = coordinator(voiceOver: true)
        coordinator.announce(.setStart(name: "深蹲", setIndex: 1, totalSets: 3, dose: "12 次", nextName: nil))
        #expect(announcer.spoken.isEmpty)
    }

    @Test("三个条件都满足才念，内容与文案一致")
    func speaksWhenAllowed() {
        let (coordinator, announcer) = coordinator()
        coordinator.announce(.setStart(name: "深蹲", setIndex: 2, totalSets: 3, dose: "12 次", nextName: "臀桥"))
        #expect(announcer.spoken == ["第 2 组，共 3 组，深蹲，12 次，下一个：臀桥"])
        #expect(coordinator.lastSpokenText == announcer.spoken.first)
    }

    @Test("没有文案时什么都不做")
    func nilAnnouncementIsIgnored() {
        let (coordinator, announcer) = coordinator()
        coordinator.announce(nil)
        #expect(announcer.spoken.isEmpty)
    }

    @Test("倒数走同一条路径，只念数字")
    func countdownSpeaksDigits() {
        let (coordinator, announcer) = coordinator()
        coordinator.announce(.restCountdown(secondsLeft: 3))
        coordinator.announce(.restCountdown(secondsLeft: 2))
        #expect(announcer.spoken == ["3", "2"])
    }

    @Test("连续节点按顺序送进引擎，后一句由引擎打断前一句")
    func sequentialNodesAreAllDelivered() {
        let (coordinator, announcer) = coordinator()
        coordinator.announce(.sessionStart(title: "测试计划", totalSets: 9))
        coordinator.announce(.setStart(name: "深蹲", setIndex: 1, totalSets: 3, dose: "12 次", nextName: nil))
        #expect(announcer.spoken.count == 2)
        #expect(coordinator.lastSpokenText?.contains("深蹲") == true)
    }

    @Test("关掉开关会立刻掐断正在念的")
    func disablingStopsCurrentSpeech() {
        let (coordinator, announcer) = coordinator()
        coordinator.announce(.restStart(seconds: 30))
        #expect(announcer.isSpeaking)

        coordinator.policy.isEnabled = false
        #expect(announcer.stopCount == 1)
        #expect(announcer.isSpeaking == false)
        #expect(coordinator.lastSpokenText == nil)
    }

    @Test("进后台同样立刻停")
    func backgroundingStopsCurrentSpeech() {
        let (coordinator, announcer) = coordinator()
        coordinator.announce(.restStart(seconds: 30))
        coordinator.policy.isForeground = false
        #expect(announcer.stopCount == 1)
    }

    @Test("回前台后能继续念")
    func resumesAfterForeground() {
        let (coordinator, announcer) = coordinator()
        coordinator.policy.isForeground = false
        coordinator.announce(.restStart(seconds: 30))
        #expect(announcer.spoken.isEmpty)

        coordinator.policy.isForeground = true
        coordinator.announce(.restFinished(nextName: "臀桥", nextDose: "12 次"))
        #expect(announcer.spoken.count == 1)
    }

    @Test("不可播状态下改策略只停一次，不反复掐")
    func repeatedDisallowedPolicyStopsOnce() {
        let (coordinator, announcer) = coordinator(enabled: false)
        #expect(announcer.stopCount == 0)
        coordinator.policy.isForeground = false
        #expect(announcer.stopCount == 1)
    }
}

@MainActor
private final class FakeAnnouncer: SpeechAnnouncing {
    private(set) var spoken: [String] = []
    private(set) var stopCount = 0
    private(set) var isSpeaking = false

    func speak(_ text: String) {
        spoken.append(text)
        isSpeaking = true
    }

    func stop() {
        stopCount += 1
        isSpeaking = false
    }
}
