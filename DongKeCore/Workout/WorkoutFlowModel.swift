import Foundation

public enum FlowStep: Equatable, Sendable {
    case set(prescriptionId: String, setIndex: Int, target: SetTarget, restAfterSec: Int)
    case roundBreak(seconds: Int)
    case blockBreak(seconds: Int, nextBlockTitle: String)
    case finished
}

public struct WorkoutFlowModel: Equatable, Sendable {
    public let steps: [FlowStep]

    public var plannedSets: Int {
        steps.reduce(into: 0) { count, step in
            if case .set = step { count += 1 }
        }
    }

    public init(plan: WorkoutPlan, dayIndex: Int) {
        steps = []
    }
}
