import Foundation

public enum FlowStep: Equatable, Sendable {
    case set(prescriptionId: String, setIndex: Int, target: SetTarget, restAfterSec: Int)
    case roundBreak(seconds: Int)
    case blockBreak(seconds: Int, nextBlockTitle: String)
    case finished
}

public struct WorkoutFlowModel: Equatable, Sendable {
    public let steps: [FlowStep]
    public let setCounts: [String: Int]

    public var plannedSets: Int {
        steps.reduce(into: 0) { count, step in
            if case .set = step { count += 1 }
        }
    }

    public init(plan: WorkoutPlan, dayIndex: Int) {
        guard let day = plan.days.first(where: { $0.dayIndex == dayIndex }), !day.isRestDay else {
            steps = [.finished]
            setCounts = [:]
            return
        }

        var built: [FlowStep] = []
        var counts: [String: Int] = [:]

        func appendSets(of item: ExercisePrescription) {
            for _ in 1...max(1, item.sets) {
                let next = (counts[item.itemId] ?? 0) + 1
                counts[item.itemId] = next
                built.append(.set(
                    prescriptionId: item.itemId,
                    setIndex: next,
                    target: item.target,
                    restAfterSec: item.restSec
                ))
            }
        }

        for (blockOffset, block) in day.blocks.enumerated() {
            let isLoop = block.kind == .circuit || block.kind == .superset
            let rounds = max(1, block.rounds)

            if isLoop {
                for round in 1...rounds {
                    for item in block.items {
                        appendSets(of: item)
                    }
                    if round < rounds, block.restBetweenRoundsSec > 0 {
                        built.append(.roundBreak(seconds: block.restBetweenRoundsSec))
                    }
                }
            } else {
                for item in block.items {
                    appendSets(of: item)
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
        setCounts = counts
    }
}
