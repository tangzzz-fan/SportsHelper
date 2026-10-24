import Foundation

public struct SetTimerDriver: Equatable, Sendable {
    public private(set) var state: SetTimerState = .idle
    public private(set) var stepIndex: Int?
    public private(set) var remainingDisplay = 0
    public private(set) var reachedZeroCount = 0
    public private(set) var isTimedStep = false

    public init() {}

    public var showsCountdown: Bool {
        isTimedStep && state != .idle
    }

    public mutating func sync(step: FlowStep?, stepIndex: Int, isResting: Bool, now: Date) {
        guard isResting == false,
              case let .set(_, _, target, _)? = step,
              target.type == .durationSec
        else {
            reset()
            return
        }
        isTimedStep = true
        guard self.stepIndex != stepIndex || state == .idle else { return }
        self.stepIndex = stepIndex
        var effects: [SetTimerEffect] = []
        state = SetTimerStateMachine.reduce(state, .start(seconds: target.value, now: now), &effects)
        remainingDisplay = target.value
        reachedZeroCount = 0
    }

    public mutating func tick(now: Date) {
        guard state != .idle else { return }
        var effects: [SetTimerEffect] = []
        let next = SetTimerStateMachine.reduce(state, .tick(now: now), &effects)
        if next != state { state = next }
        if effects.contains(.reachedZero) {
            reachedZeroCount += 1
        }
        let remaining = Int(SetTimerStateMachine.remaining(state, now: now).rounded(.up))
        if remainingDisplay != remaining {
            remainingDisplay = remaining
        }
    }

    public func elapsedSeconds(now: Date) -> Int {
        SetTimerStateMachine.elapsedSeconds(state, now: now)
    }

    public mutating func reset() {
        guard state != .idle || isTimedStep || stepIndex != nil || remainingDisplay != 0 else { return }
        var effects: [SetTimerEffect] = []
        state = SetTimerStateMachine.reduce(state, .reset, &effects)
        stepIndex = nil
        remainingDisplay = 0
        isTimedStep = false
    }
}
