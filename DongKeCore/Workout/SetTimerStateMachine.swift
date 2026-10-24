import Foundation

public enum SetTimerState: Equatable, Sendable {
    case idle
    case running(startedAt: Date, endAt: Date, totalSeconds: Int)
    case elapsed(totalSeconds: Int)
}

public enum SetTimerEvent: Equatable, Sendable {
    case start(seconds: Int, now: Date)
    case tick(now: Date)
    case reset
}

public enum SetTimerEffect: Equatable, Sendable {
    case reachedZero
}

public enum SetTimerStateMachine {
    public static func reduce(
        _ state: SetTimerState,
        _ event: SetTimerEvent,
        _ effects: inout [SetTimerEffect]
    ) -> SetTimerState {
        switch event {
        case .start(let seconds, let now):
            guard seconds > 0 else { return .idle }
            return .running(
                startedAt: now,
                endAt: now.addingTimeInterval(TimeInterval(seconds)),
                totalSeconds: seconds
            )

        case .tick(let now):
            guard case .running(_, let endAt, let total) = state else { return state }
            guard now >= endAt else { return state }
            effects.append(.reachedZero)
            return .elapsed(totalSeconds: total)

        case .reset:
            return .idle
        }
    }

    public static func remaining(_ state: SetTimerState, now: Date) -> TimeInterval {
        switch state {
        case .running(_, let endAt, _):
            return max(0, endAt.timeIntervalSince(now))
        case .idle, .elapsed:
            return 0
        }
    }

    public static func elapsedSeconds(_ state: SetTimerState, now: Date) -> Int {
        switch state {
        case .running(let startedAt, _, let total):
            let passed = Int(now.timeIntervalSince(startedAt).rounded(.down))
            return min(total, max(0, passed))
        case .elapsed(let total):
            return total
        case .idle:
            return 0
        }
    }
}
