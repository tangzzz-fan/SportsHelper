import Foundation
import Observation
import DongKeCore

@MainActor
@Observable
final class WatchWorkoutSession {
    private(set) var restState: RestState = .idle
    private(set) var now = Date()
    private var lastContextUpdatedAt: Date?

    var isResting: Bool {
        switch restState {
        case .running, .paused:
            return true
        case .idle, .finished:
            return false
        }
    }

    var remainingSeconds: Int {
        Int(RestTimerStateMachine.remaining(restState, now: now).rounded(.up))
    }

    /// 只在上下文的 `updatedAt` 变化时重算休息，否则 Watch 本地「+15 秒」会被
    /// 同一份旧上下文在下一个 tick 抹掉。
    func sync(with context: WatchContext, now: Date = Date()) {
        guard context.checkpoint.updatedAt != lastContextUpdatedAt else { return }
        lastContextUpdatedAt = context.checkpoint.updatedAt
        self.now = now
        guard context.checkpoint.status == .inProgress,
              let endAt = context.checkpoint.restEndsAt,
              context.checkpoint.restTotalSeconds > 0,
              endAt > now
        else {
            restState = .idle
            return
        }
        restState = .running(endAt: endAt, totalSeconds: context.checkpoint.restTotalSeconds)
    }

    /// 每 0.25 秒由视图调用。进后台后再回来，第一次 tick 会按绝对时间直接跳到 finished。
    func tick(now: Date = Date()) {
        guard case .running = restState else { return }
        self.now = now
        var effects: [RestEffect] = []
        let next = RestTimerStateMachine.reduce(restState, .tick(now: now), &effects)
        if next != restState {
            restState = next
        }
    }

    func extend(by seconds: Int = 15, now: Date = Date()) {
        self.now = now
        var effects: [RestEffect] = []
        restState = RestTimerStateMachine.reduce(restState, .extend(seconds: seconds, now: now), &effects)
    }

    func finishRest() {
        var effects: [RestEffect] = []
        restState = RestTimerStateMachine.reduce(restState, .skip, &effects)
    }

    func startRest(seconds: Int, now: Date = Date()) {
        self.now = now
        var effects: [RestEffect] = []
        restState = RestTimerStateMachine.reduce(restState, .start(seconds: seconds, now: now), &effects)
    }
}
