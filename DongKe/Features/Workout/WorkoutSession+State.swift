import Foundation
import DongKeCore

extension WorkoutSession {
    func finish(now: Date) {
        guard finishedAt == nil else { return }
        finishedAt = now
        persist(finishedAt: now)
        saveCheckpoint(now: now)
        voice?.finished(completedSets: completedSets)
    }

    func appendLog(_ log: SetLog, now: Date) {
        logs.append(log)
        setLogStore?.add(log)
        persist()
        saveCheckpoint(now: now)
    }

    func saveCheckpoint(now: Date = Date()) {
        syncRestNotification()
        guard let checkpointStore else { return }
        guard finishedAt == nil else {
            checkpointStore.clear()
            return
        }
        var restEndsAt: Date?
        var restTotal = 0
        if case let .running(endAt, total) = rest {
            restEndsAt = endAt
            restTotal = total
        }
        checkpointStore.save(WorkoutCheckpoint(
            sessionId: id,
            dayIndex: dayIndex,
            stepIndex: stepIndex,
            totalSteps: flow.steps.count,
            startedAt: startedAt,
            updatedAt: now,
            restEndsAt: restEndsAt,
            restTotalSeconds: restTotal,
            logs: logs
        ))
    }

    func persist(finishedAt: Date? = nil) {
        store?.upsert(
            id: id,
            title: sessionTitle,
            plannedSets: plannedSets,
            completedSets: completedSets,
            startedAt: startedAt,
            finishedAt: finishedAt,
            planDate: planDate
        )
    }

    func beginRestIfNeeded(seconds: Int, kicker: String, now: Date) {
        if case .finished? = nextStep {
            advance()
            return
        }
        guard seconds > 0 else {
            advance()
            return
        }
        startRest(seconds: seconds, kicker: kicker, now: now)
    }

    var nextStep: FlowStep? {
        stepIndex + 1 < flow.steps.count ? flow.steps[stepIndex + 1] : nil
    }

    func startRest(seconds: Int, kicker: String, now: Date) {
        restKicker = kicker
        var effects: [RestEffect] = []
        rest = RestTimerStateMachine.reduce(rest, .start(seconds: seconds, now: now), &effects)
        resetSetTimer()
        saveCheckpoint(now: now)
        voice?.restStarted(seconds: seconds, at: stepIndex)
    }

    func syncRestNotification() {
        guard let restNotifications else { return }
        if case let .running(endAt, _) = rest {
            restNotifications.scheduleRestEnd(
                dayIndex: dayIndex,
                sessionId: id,
                endsAt: endAt,
                nextTitle: restKicker
            )
        } else {
            restNotifications.cancelRestEnd()
        }
    }

    func advance(silent: Bool = false) {
        rest = .idle
        guard stepIndex + 1 < flow.steps.count else {
            saveCheckpoint()
            return
        }
        stepIndex += 1
        autoStartRestIfBreak(now: Date())
        syncSetTimer()
        saveCheckpoint()
        voice?.stepChanged(to: stepIndex, silent: silent)
    }

    func syncSetTimer(now: Date = Date()) {
        setTimer.sync(step: currentStep, stepIndex: stepIndex, isResting: isResting, now: now)
    }

    func resetSetTimer() {
        setTimer.reset()
    }

    func autoStartRestIfBreak(now: Date) {
        switch currentStep {
        case let .roundBreak(seconds)?:
            startRest(seconds: seconds, kicker: "回合休息", now: now)
        case let .blockBreak(seconds, nextTitle)?:
            startRest(seconds: seconds, kicker: "下一项 · \(nextTitle)", now: now)
        case .finished?:
            finish(now: now)
        default:
            break
        }
    }
}
