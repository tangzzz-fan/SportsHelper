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
        state
    }

    public static func remaining(_ state: RestState, now: Date) -> TimeInterval {
        0
    }
}
