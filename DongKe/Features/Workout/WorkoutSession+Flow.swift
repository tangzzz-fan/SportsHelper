import Foundation
import DongKeCore

extension WorkoutSession {
    func completeSet(bonus: Int = 0, rpe: Int? = nil, now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec)? = currentStep else {
            advance()
            return
        }
        let actual = target.value + max(0, bonus)
        noteRecordIfBroken(actual: actual, target: target, now: now)
        appendLog(SetLog(
            sessionId: id,
            prescriptionId: prescriptionId,
            catalogId: currentPrescription?.catalogId,
            targetType: target.type,
            setIndex: setIndex,
            status: .done,
            plannedValue: target.value,
            actualValue: actual,
            rpe: rpe,
            completedAt: now,
            origin: isExtraCurrentSet ? .extra : .prescribed
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
            catalogId: currentPrescription?.catalogId,
            targetType: target.type,
            setIndex: setIndex,
            status: .downgraded,
            plannedValue: target.value,
            actualValue: max(1, target.value / 2),
            skipReason: .tooHard,
            completedAt: now,
            origin: isExtraCurrentSet ? .extra : .prescribed
        ), now: now)
        beginRestIfNeeded(seconds: restAfterSec, kicker: "组间休息", now: now)
    }

    func skipSet(reason: SkipReason = .noTime, now: Date = Date()) {
        guard case let .set(prescriptionId, setIndex, target, _)? = currentStep else {
            advance()
            return
        }
        if isExtraCurrentSet {
            advance(silent: true)
            saveCheckpoint(now: now)
            return
        }
        appendLog(.skipped(
            sessionId: id,
            prescriptionId: prescriptionId,
            catalogId: currentPrescription?.catalogId,
            targetType: target.type,
            setIndex: setIndex,
            plannedValue: target.value,
            reason: reason,
            at: now
        ), now: now)
        advance(silent: true)
        saveCheckpoint(now: now)
    }

    private func noteRecordIfBroken(actual: Int, target: SetTarget, now: Date) {
        guard target.type != .distanceM,
              let catalogId = currentPrescription?.catalogId,
              celebratedActions.contains(catalogId) == false,
              let setLogStore
        else { return }

        let logs = setLogStore.logs(forCatalogIds: [catalogId], before: now)
        let best = PersonalRecords.build(logs: logs)[RecordKey(catalogId: catalogId, unit: target.type)]?.best
        guard RecordGate.isRecord(best: best, actual: actual) else { return }

        celebratedActions.insert(catalogId)
        recordCelebration = RecordCelebration.text(
            name: currentPrescription?.name ?? "",
            value: actual,
            unit: target.type
        )
        if recordCelebration != nil { Haptics.recordBroken() }
    }

    func refresh(now: Date = Date()) {
        syncSetTimer(now: now)
        tickSetTimer(now: now)

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

    func tickSetTimer(now: Date) {
        guard setTimer.state != .idle else { return }
        setTimer.tick(now: now)
        voice?.setElapsed(setTimer.elapsedSeconds(now: now))
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

    func addExtraSet(now: Date = Date()) {
        guard canAddExtraSet,
              case let .set(id, setIndex, target, restAfterSec)? = currentStep else { return }
        let planned = flow.setCounts[id] ?? setIndex
        let nextIndex = max(setIndex, planned) + 1
        script = WorkoutFlowModel.insertingExtraSet(
            in: script,
            after: stepIndex,
            prescriptionId: id,
            setIndex: nextIndex,
            target: target,
            restAfterSec: restAfterSec
        )
        voice?.updateScript(script)
        saveCheckpoint(now: now)
    }

    func undoExtraSet(now: Date = Date()) {
        guard hasQueuedExtra else { return }
        script.remove(at: stepIndex + 1)
        voice?.updateScript(script)
        saveCheckpoint(now: now)
    }

    func endWorkout() {
        rest = .idle
        finish(now: Date())
    }
}
