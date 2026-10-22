import Foundation

public enum RestState: Equatable, Sendable {
    case idle
    case running(endAt: Date, totalSeconds: Int)
    case paused(remaining: TimeInterval, totalSeconds: Int)
    case finished(totalSeconds: Int)
}

public enum RestEvent: Equatable, Sendable {
    case start(seconds: Int, now: Date)
    case tick(now: Date)
    case pause(now: Date)
    case resume(now: Date)
    case extend(seconds: Int, now: Date)
    case skip
    case cancel
}

public enum RestEffect: Equatable, Sendable {
    case scheduleNotification(endAt: Date)
    case cancelNotification
    case playHaptic
    case autoAdvanceToNextSet
}

public enum RestTimerStateMachine {
    public static func reduce(
        _ state: RestState,
        _ event: RestEvent,
        _ effects: inout [RestEffect]
    ) -> RestState {
        switch event {
        case .start(let seconds, let now):
            guard seconds > 0 else { return .idle }
            let endAt = now.addingTimeInterval(TimeInterval(seconds))
            effects.append(.scheduleNotification(endAt: endAt))
            return .running(endAt: endAt, totalSeconds: seconds)

        case .tick(let now):
            guard case .running(let endAt, let total) = state else { return state }
            guard now >= endAt else { return state }
            effects.append(.playHaptic)
            effects.append(.autoAdvanceToNextSet)
            return .finished(totalSeconds: total)

        case .pause(let now):
            guard case .running(let endAt, let total) = state else { return state }
            let remaining = max(0, endAt.timeIntervalSince(now))
            effects.append(.cancelNotification)
            return .paused(remaining: remaining, totalSeconds: total)

        case .resume(let now):
            guard case .paused(let remaining, let total) = state else { return state }
            let endAt = now.addingTimeInterval(remaining)
            effects.append(.scheduleNotification(endAt: endAt))
            return .running(endAt: endAt, totalSeconds: total)

        case .extend(let seconds, _):
            switch state {
            case .running(let endAt, let total):
                let newEnd = endAt.addingTimeInterval(TimeInterval(seconds))
                effects.append(.scheduleNotification(endAt: newEnd))
                return .running(endAt: newEnd, totalSeconds: total + seconds)
            case .paused(let remaining, let total):
                return .paused(
                    remaining: max(0, remaining + TimeInterval(seconds)),
                    totalSeconds: total + seconds
                )
            case .idle, .finished:
                return state
            }

        case .skip, .cancel:
            guard state != .idle else { return state }
            effects.append(.cancelNotification)
            return .idle
        }
    }

    public static func remaining(_ state: RestState, now: Date) -> TimeInterval {
        switch state {
        case .running(let endAt, _):
            return max(0, endAt.timeIntervalSince(now))
        case .paused(let remaining, _):
            return max(0, remaining)
        case .idle, .finished:
            return 0
        }
    }
}
