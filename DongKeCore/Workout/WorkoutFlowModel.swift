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
        guard let day = plan.days.first(where: { $0.dayIndex == dayIndex }), !day.isRestDay else {
            steps = [.finished]
            return
        }

        var built: [FlowStep] = []

        for (blockOffset, block) in day.blocks.enumerated() {
            let isLoop = block.kind == .circuit || block.kind == .superset
            let rounds = max(1, block.rounds)

            if isLoop {
                for round in 1...rounds {
                    for item in block.items {
                        for setIndex in 1...max(1, item.sets) {
                            built.append(.set(
                                prescriptionId: item.itemId,
                                setIndex: setIndex,
                                target: item.target,
                                restAfterSec: item.restSec
                            ))
                        }
                    }
                    if round < rounds, block.restBetweenRoundsSec > 0 {
                        built.append(.roundBreak(seconds: block.restBetweenRoundsSec))
                    }
                }
            } else {
                for item in block.items {
                    for setIndex in 1...max(1, item.sets) {
                        built.append(.set(
                            prescriptionId: item.itemId,
                            setIndex: setIndex,
                            target: item.target,
                            restAfterSec: item.restSec
                        ))
                    }
                }
            }

            if blockOffset < day.blocks.count - 1 {
                built.append(.blockBreak(
                    seconds: block.restBetweenItemsSec,
                    nextBlockTitle: day.blocks[blockOffset + 1].title
                ))
            }
        }

        built.append(.finished)
        steps = built
    }
}
