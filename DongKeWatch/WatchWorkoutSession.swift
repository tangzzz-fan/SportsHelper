import Foundation
import Observation
import DongKeCore

struct WatchSetSummary: Equatable {
    var name: String
    var prescriptionId: String
    var catalogId: String
    var setIndex: Int
    var setCount: Int
    var targetType: SetTargetType
    var targetValue: Int
    var targetText: String
    var restAfterSec: Int

    static func set(at index: Int, in context: WatchContext) -> WatchSetSummary? {
        guard let steps = context.checkpoint.steps, steps.indices.contains(index) else {
            return nil
        }
        return summary(from: steps[index], in: context)
    }

    static func nextSet(atOrAfter index: Int, in context: WatchContext) -> WatchSetSummary? {
        guard let steps = context.checkpoint.steps,
              !steps.isEmpty,
              steps.indices.contains(index)
        else {
            return nil
        }
        for candidate in index..<steps.count {
            if let summary = summary(from: steps[candidate], in: context) {
                return summary
            }
        }
        return nil
    }

    private static func summary(from step: FlowStep, in context: WatchContext) -> WatchSetSummary? {
        guard case let .set(prescriptionId, setIndex, target, restAfterSec) = step,
              let exercise = context.exercise(for: prescriptionId)
        else {
            return nil
        }
        return WatchSetSummary(
            name: exercise.name,
            prescriptionId: prescriptionId,
            catalogId: exercise.catalogId,
            setIndex: setIndex,
            setCount: exercise.setCount,
            targetType: target.type,
            targetValue: target.value,
            targetText: target.perSide ? "每侧 \(target.doseText)" : target.doseText,
            restAfterSec: restAfterSec
        )
    }
}

@MainActor
@Observable
final class WatchWorkoutSession {
    private(set) var restState: RestState = .idle
    private(set) var now = Date()
    private(set) var localStepIndex = 0
    private(set) var pendingCount = 0
    private(set) var logStatusText: String?

    private var lastContextUpdatedAt: Date?
    private var contextSessionId: UUID?
    private var contextRevision: Int?
    private var retryTask: Task<Void, Never>?
    private let queue: PendingLogQueue

    init(queue: PendingLogQueue = PendingLogQueue(store: .live)) {
        self.queue = queue
    }

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

    func resolvedStepIndex(in context: WatchContext) -> Int {
        guard context.checkpoint.sessionId == contextSessionId else {
            return context.checkpoint.stepIndex
        }
        return max(localStepIndex, context.checkpoint.stepIndex)
    }

    func currentSet(in context: WatchContext) -> WatchSetSummary? {
        WatchSetSummary.nextSet(atOrAfter: resolvedStepIndex(in: context), in: context)
    }

    /// 只在上下文的 `updatedAt` 变化时重算休息，否则 Watch 本地「+15 秒」会被
    /// 同一份旧上下文在下一个 tick 抹掉。
    func sync(with context: WatchContext, now: Date = Date()) {
        if context.checkpoint.sessionId != contextSessionId
            || context.checkpoint.revision != contextRevision {
            contextSessionId = context.checkpoint.sessionId
            contextRevision = context.checkpoint.revision
            localStepIndex = context.checkpoint.stepIndex
            retryTask?.cancel()
        } else {
            localStepIndex = max(localStepIndex, context.checkpoint.stepIndex)
        }

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
        guard seconds > 0 else { return }
        self.now = now
        var effects: [RestEffect] = []
        restState = RestTimerStateMachine.reduce(restState, .start(seconds: seconds, now: now), &effects)
    }

    func completeSet(in context: WatchContext, now: Date = Date()) {
        let index = resolvedStepIndex(in: context)
        guard let set = WatchSetSummary.set(at: index, in: context) else { return }

        let log = SetLog(
            sessionId: context.checkpoint.sessionId,
            prescriptionId: set.prescriptionId,
            catalogId: set.catalogId,
            targetType: set.targetType,
            setIndex: set.setIndex,
            status: .done,
            plannedValue: set.targetValue,
            actualValue: set.targetValue,
            completedAt: now
        )
        pendingCount += 1
        logStatusText = "已记录（同步中）"
        Task { await enqueueAndFlush(log) }

        if let steps = context.checkpoint.steps, index + 1 < steps.count {
            localStepIndex = index + 1
        }
        startRest(seconds: set.restAfterSec, now: now)
    }

    func refreshPending() {
        Task {
            let count = (try? await queue.pendingCount()) ?? 0
            pendingCount = count
            if count > 0, (try? await queue.needsUserAlert()) == true {
                logStatusText = "待同步超过 24 小时，请打开 iPhone"
            } else if count > 0 {
                logStatusText = "待同步（\(count) 组）"
            }
        }
    }

    func flushPending() {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            guard let self else { return }
            var delay: TimeInterval = 0
            for _ in 0..<4 {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled { return }
                }
                let outcome = await queue.flush(using: WatchLogSender(), now: Date())
                switch outcome {
                case let .sent(count):
                    pendingCount = 0
                    logStatusText = "已同步（\(count) 组）"
                    return
                case .empty:
                    pendingCount = 0
                    return
                case let .failed(_, remaining, retryAfter):
                    pendingCount = remaining
                    logStatusText = "待同步（\(remaining) 组）"
                    delay = retryAfter
                case let .backingOff(until):
                    delay = max(1, until.timeIntervalSinceNow)
                case .busy:
                    return
                }
            }
        }
    }

    private func enqueueAndFlush(_ log: SetLog) async {
        do {
            pendingCount = try await queue.enqueue(log)
        } catch {
            logStatusText = "本地暂存失败"
            return
        }
        flushPending()
    }
}
