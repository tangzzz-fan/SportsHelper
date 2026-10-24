import Foundation
import Testing
@testable import DongKeCore

struct SetTimerStateMachineTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func started(_ seconds: Int) -> SetTimerState {
        var effects: [SetTimerEffect] = []
        return SetTimerStateMachine.reduce(.idle, .start(seconds: seconds, now: start), &effects)
    }

    private func tick(_ state: SetTimerState, after seconds: TimeInterval) -> (SetTimerState, [SetTimerEffect]) {
        var effects: [SetTimerEffect] = []
        let next = SetTimerStateMachine.reduce(
            state,
            .tick(now: start.addingTimeInterval(seconds)),
            &effects
        )
        return (next, effects)
    }

    @Test("启动后剩余等于整段时长")
    func startsAtFullDuration() {
        let state = started(30)
        #expect(SetTimerStateMachine.remaining(state, now: start) == 30)
        #expect(SetTimerStateMachine.elapsedSeconds(state, now: start) == 0)
    }

    @Test("过半时剩余与已用时长互补")
    func remainingTracksClock() {
        let state = started(30)
        let mid = start.addingTimeInterval(12)
        #expect(SetTimerStateMachine.remaining(state, now: mid) == 18)
        #expect(SetTimerStateMachine.elapsedSeconds(state, now: mid) == 12)
    }

    @Test("到点转 elapsed 并只触发一次")
    func reachesZeroOnce() {
        let state = started(30)
        let (done, effects) = tick(state, after: 30)
        #expect(done == .elapsed(totalSeconds: 30))
        #expect(effects == [.reachedZero])

        let (stillDone, laterEffects) = tick(done, after: 45)
        #expect(stillDone == .elapsed(totalSeconds: 30))
        #expect(laterEffects.isEmpty)
    }

    @Test("未到点 tick 不改状态也不触发")
    func tickBeforeZeroKeepsRunning() {
        let state = started(30)
        let (next, effects) = tick(state, after: 29.75)
        #expect(next == state)
        #expect(effects.isEmpty)
        #expect(SetTimerStateMachine.elapsedSeconds(next, now: start.addingTimeInterval(29.75)) == 29)
    }

    @Test("零秒不启动，免得白占一个倒计时")
    func zeroSecondsStaysIdle() {
        var effects: [SetTimerEffect] = []
        let state = SetTimerStateMachine.reduce(.idle, .start(seconds: 0, now: start), &effects)
        #expect(state == .idle)
        #expect(effects.isEmpty)
    }

    @Test("重置回 idle，剩余归零")
    func resetClearsState() {
        var effects: [SetTimerEffect] = []
        let state = SetTimerStateMachine.reduce(started(30), .reset, &effects)
        #expect(state == .idle)
        #expect(SetTimerStateMachine.remaining(state, now: start) == 0)
        #expect(SetTimerStateMachine.elapsedSeconds(state, now: start) == 0)
    }

    @Test("到点后已用时长停在整段，不随真实时间继续涨")
    func elapsedClampsAtTotal() {
        var effects: [SetTimerEffect] = []
        let done = SetTimerStateMachine.reduce(
            started(30),
            .tick(now: start.addingTimeInterval(60)),
            &effects
        )
        #expect(done == .elapsed(totalSeconds: 30))
        #expect(SetTimerStateMachine.elapsedSeconds(done, now: start.addingTimeInterval(120)) == 30)
    }

    @Test("时钟回拨时不出现负数")
    func negativeElapsedFloorsAtZero() {
        let state = started(30)
        let earlier = start.addingTimeInterval(-5)
        #expect(SetTimerStateMachine.elapsedSeconds(state, now: earlier) == 0)
        #expect(SetTimerStateMachine.remaining(state, now: earlier) == 35)
    }
}
