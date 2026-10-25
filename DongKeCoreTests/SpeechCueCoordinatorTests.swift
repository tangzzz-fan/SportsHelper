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
    ) -> (SpeechCueCoordinator, FakeRenderer) {
        let renderer = FakeRenderer()
        let coordinator = SpeechCueCoordinator(
            policy: SpeechCuePolicy(
                isEnabled: enabled,
                isForeground: foreground,
                isVoiceOverRunning: voiceOver
            ),
            renderer: renderer
        )
        return (coordinator, renderer)
    }

    @Test("开关关着时一句都不念")
    func disabledStaysSilent() {
        let (coordinator, renderer) = coordinator(enabled: false)
        coordinator.announce(.restStart(seconds: 30))
        #expect(renderer.spoken.isEmpty)
        #expect(coordinator.lastSpokenText == nil)
    }

    @Test("App 在后台时不念")
    func backgroundStaysSilent() {
        let (coordinator, renderer) = coordinator(foreground: false)
        coordinator.announce(.restStart(seconds: 30))
        #expect(renderer.spoken.isEmpty)
    }

    @Test("VoiceOver 开着时让路")
    func voiceOverYields() {
        let (coordinator, renderer) = coordinator(voiceOver: true)
        coordinator.announce(.setStart(name: "深蹲", setIndex: 1, totalSets: 3, dose: "12 次"))
        #expect(renderer.spoken.isEmpty)
    }

    @Test("三个条件都满足才念，内容与文案一致")
    func speaksWhenAllowed() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.setStart(name: "深蹲", setIndex: 2, totalSets: 3, dose: "12 次"))
        #expect(renderer.spoken == ["深蹲，第 2 组，共 3 组，12 次"])
        #expect(coordinator.lastSpokenText == renderer.spoken.first)
    }

    @Test("没有文案时什么都不做")
    func nilAnnouncementIsIgnored() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(nil)
        #expect(renderer.spoken.isEmpty)
    }

    @Test("倒数走同一条路径，只念数字")
    func countdownSpeaksDigits() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.restCountdown(secondsLeft: 3))
        coordinator.announce(.restCountdown(secondsLeft: 2))
        #expect(renderer.spoken == ["3", "2"])
    }

    @Test("同优先级的新句替换旧句，旧句被取消")
    func samePriorityReplaces() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.setStart(name: "深蹲", setIndex: 1, totalSets: 3, dose: "12 次"))
        coordinator.announce(.setStart(name: "深蹲", setIndex: 2, totalSets: 3, dose: "12 次"))
        #expect(renderer.spoken.count == 2)
        #expect(renderer.cancelled == 1)
        #expect(coordinator.lastSpokenText == "深蹲，第 2 组，共 3 组，12 次")
    }

    @Test("低优先级不打断正在念的指令")
    func lowerPriorityIsDropped() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.setStart(name: "深蹲", setIndex: 1, totalSets: 3, dose: "12 次"))
        coordinator.announce(.restStart(seconds: 30))
        #expect(renderer.spoken == ["深蹲，第 1 组，共 3 组，12 次"])
        #expect(renderer.cancelled == 0)
    }

    @Test("倒数可以打断提示")
    func countdownPreemptsAside() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.restStart(seconds: 30))
        coordinator.announce(.restCountdown(secondsLeft: 3))
        #expect(renderer.spoken == ["休息，30 秒", "3"])
        #expect(renderer.cancelled == 1)
    }

    @Test("关掉开关会立刻掐断正在念的")
    func disablingStopsCurrentSpeech() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.restStart(seconds: 30))
        #expect(coordinator.isSpeaking)

        coordinator.policy.isEnabled = false
        #expect(renderer.cancelled == 1)
        #expect(coordinator.isSpeaking == false)
        #expect(coordinator.lastSpokenText == nil)
    }

    @Test("进后台同样立刻停")
    func backgroundingStopsCurrentSpeech() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.restStart(seconds: 30))
        coordinator.policy.isForeground = false
        #expect(renderer.cancelled == 1)
    }

    @Test("念完之后可以继续念下一句")
    func resumesAfterFinish() {
        let (coordinator, renderer) = coordinator()
        coordinator.announce(.restStart(seconds: 30))
        renderer.finish()
        #expect(coordinator.isSpeaking == false)

        coordinator.announce(.restFinished)
        #expect(renderer.spoken == ["休息，30 秒", "休息结束"])
    }

    @Test("不可播状态下改策略只停一次，不反复掐")
    func repeatedDisallowedPolicyStopsOnce() {
        let (coordinator, renderer) = coordinator(enabled: false)
        #expect(renderer.cancelled == 0)
        coordinator.policy.isForeground = false
        #expect(renderer.cancelled == 1)
    }
}

@MainActor
private final class FakeRenderer: SpeechRendering {
    private(set) var spoken: [String] = []
    private(set) var cancelled = 0

    private var currentID: UUID?
    private var handler: ((SpeechOutputEvent) -> Void)?

    var availability: SpeechAvailability { .ready }

    var profile: SpeechProfile {
        SpeechProfile(engineId: "fake", voiceName: "假引擎", charactersPerSecond: 4)
    }

    func prepare() {}

    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void) {
        spoken.append(request.text)
        currentID = request.id
        handler = event
        event(.started(request.id))
    }

    func cancel() {
        cancelled += 1
        if let currentID {
            handler?(.cancelled(currentID, .stopped))
        }
        currentID = nil
    }

    func finish() {
        if let currentID {
            handler?(.finished(currentID, seconds: 1))
        }
        currentID = nil
    }
}
