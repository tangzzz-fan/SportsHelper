import Foundation
import Testing
@testable import DongKeCore

@Suite("RestTimerStateMachine")
struct RestTimerStateMachineTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func startSchedulesNotification() {
        var effects: [RestEffect] = []
        let state = RestTimerStateMachine.reduce(.idle, .start(seconds: 90, now: t0), &effects)

        #expect(state == .running(endAt: t0.addingTimeInterval(90), totalSeconds: 90))
        #expect(effects == [.scheduleNotification(endAt: t0.addingTimeInterval(90))])
    }

    @Test func tickBeforeEndKeepsRunning() {
        var effects: [RestEffect] = []
        let running = RestState.running(endAt: t0.addingTimeInterval(90), totalSeconds: 90)
        let state = RestTimerStateMachine.reduce(running, .tick(now: t0.addingTimeInterval(30)), &effects)

        #expect(state == running)
        #expect(effects.isEmpty)
        #expect(RestTimerStateMachine.remaining(state, now: t0.addingTimeInterval(30)) == 60)
    }

    @Test func tickAtEndFinishesOnce() {
        var effects: [RestEffect] = []
        let running = RestState.running(endAt: t0.addingTimeInterval(90), totalSeconds: 90)
        let state = RestTimerStateMachine.reduce(running, .tick(now: t0.addingTimeInterval(90)), &effects)

        #expect(state == .finished(totalSeconds: 90))
        #expect(effects.contains(.playHaptic))
        #expect(effects.contains(.autoAdvanceToNextSet))

        var repeatEffects: [RestEffect] = []
        _ = RestTimerStateMachine.reduce(state, .tick(now: t0.addingTimeInterval(100)), &repeatEffects)
        #expect(repeatEffects.isEmpty)
    }

    @Test func pauseStoresRemaining() {
        var effects: [RestEffect] = []
        let running = RestState.running(endAt: t0.addingTimeInterval(90), totalSeconds: 90)
        let state = RestTimerStateMachine.reduce(running, .pause(now: t0.addingTimeInterval(30)), &effects)

        #expect(state == .paused(remaining: 60, totalSeconds: 90))
        #expect(effects == [.cancelNotification])
    }

    @Test func resumeRebuildsEndAt() {
        var effects: [RestEffect] = []
        let resumedAt = t0.addingTimeInterval(120)
        let state = RestTimerStateMachine.reduce(.paused(remaining: 60, totalSeconds: 90), .resume(now: resumedAt), &effects)

        #expect(state == .running(endAt: resumedAt.addingTimeInterval(60), totalSeconds: 90))
        #expect(effects == [.scheduleNotification(endAt: resumedAt.addingTimeInterval(60))])
    }

    @Test func extendRunningMovesEndAt() {
        var effects: [RestEffect] = []
        let running = RestState.running(endAt: t0.addingTimeInterval(90), totalSeconds: 90)
        let state = RestTimerStateMachine.reduce(running, .extend(seconds: 15, now: t0.addingTimeInterval(10)), &effects)

        #expect(state == .running(endAt: t0.addingTimeInterval(105), totalSeconds: 105))
        #expect(effects == [.scheduleNotification(endAt: t0.addingTimeInterval(105))])
    }

    @Test func skipReturnsIdleAndCancels() {
        var effects: [RestEffect] = []
        let running = RestState.running(endAt: t0.addingTimeInterval(90), totalSeconds: 90)
        let state = RestTimerStateMachine.reduce(running, .skip, &effects)

        #expect(state == .idle)
        #expect(effects == [.cancelNotification])
    }

    @Test func backgroundJumpFinishesInSingleTick() {
        var effects: [RestEffect] = []
        let running = RestState.running(endAt: t0.addingTimeInterval(90), totalSeconds: 90)
        let state = RestTimerStateMachine.reduce(running, .tick(now: t0.addingTimeInterval(690)), &effects)

        #expect(state == .finished(totalSeconds: 90))
        #expect(RestTimerStateMachine.remaining(state, now: t0.addingTimeInterval(690)) == 0)
    }
}
