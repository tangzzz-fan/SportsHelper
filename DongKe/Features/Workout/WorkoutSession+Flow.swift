import Foundation
import DongKeCore

extension WorkoutSession {
    func completeSet(now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec)? = currentStep else {
            advance()
            return
        }
        appendLog(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            status: .done,
            plannedValue: target.value,
            actualValue: target.value,
            completedAt: now
        ), now: now)
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func downgradeSet(now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec)? = currentStep else {
            advance()
            return
        }
        appendLog(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            status: .downgraded,
            plannedValue: target.value,
            actualValue: max(1, target.value / 2),
            skipReason: .tooHard,
            completedAt: now
        ), now: now)
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func skipSet(reason: SkipReason = .noTime, now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, _)? = currentStep else {
            advance()
            return
        }
        appendLog(.skipped(
            sessionId: id,
            prescriptionId: prescriptionId,
            setIndex: setIndex,
            plannedValue: target.value,
            reason: reason,
            at: now
        ), now: now)
        advance(silent: true)
        saveCheckpoint(now: now)
    }

    func refresh(now: Date = Date()) {
        var effects: [RestEffect] = []
        let next = RestTimerStateMachine.reduce(rest, .tick(now: now), &effects)
        if next != rest { rest = next }
        if effects.contains(.playHaptic) {
            restFinishedToken += 1
            voice?.restFinished(nextStepIndex: stepIndex + 1)
        }
        if effects.contains(.autoAdvanceToNextSet) {
            rest = .idle
            advance()
            saveCheckpoint(now: now)
        }
        if case .running = rest {
            voice?.restTick(secondsLeft: Int(remainingRest(now: now).rounded(.up)))
        }
    }

    func extendRest(by seconds: Int = 15, now: Date = Date()) {
        var effects: [RestEffect] = []
        rest = RestTimerStateMachine.reduce(rest, .extend(seconds: seconds, now: now), &effects)
        saveCheckpoint(now: now)
    }

    func togglePauseRest(now: Date = Date()) {
        var effects: [RestEffect] = []
        switch rest {
        case .running:
            rest = RestTimerStateMachine.reduce(rest, .pause(now: now), &effects)
        case .paused:
            rest = RestTimerStateMachine.reduce(rest, .resume(now: now), &effects)
        default:
            break
        }
        saveCheckpoint(now: now)
    }

    func skipRest(now: Date = Date()) {
        rest = .idle
        advance()
        saveCheckpoint(now: now)
    }

    func endWorkout() {
        rest = .idle
        finish(now: Date())
    }
}
