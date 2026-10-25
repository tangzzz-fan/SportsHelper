import Foundation

public enum FlowStep: Equatable, Codable, Sendable {
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

    public func isLastSet(of prescriptionId: String, at stepIndex: Int) -> Bool {
        guard stepIndex < steps.count else { return false }
        return steps.dropFirst(stepIndex + 1).contains { step in
            if case let .set(id, _, _, _) = step { return id == prescriptionId }
            return false
        } == false
    }

    /// 下一步是不是「加出来的」那一组：同动作、且组序超出计划组数。
    ///
    /// 不能只看「下一步还是同一个动作的组」——那是最普通的组间休息，
    /// 结果是每次休息都显示「已加一组」，而「撤销」会把正常的那一组删掉。
    public func hasQueuedExtraSet(at index: Int, in steps: [FlowStep]) -> Bool {
        guard steps.indices.contains(index),
              case let .set(id, setIndex, _, _) = steps[index],
              steps.indices.contains(index + 1),
              case let .set(nextId, nextSetIndex, _, _) = steps[index + 1],
              nextId == id
        else { return false }
        let planned = setCounts[id] ?? 0
        return nextSetIndex > planned && nextSetIndex > setIndex
    }

    public static func insertingExtraSet(
        in steps: [FlowStep],
        after index: Int,
        prescriptionId: String,
        setIndex: Int,
        target: SetTarget,
        restAfterSec: Int
    ) -> [FlowStep] {
        guard steps.indices.contains(index), case .set = steps[index] else { return steps }
        var next = steps
        next.insert(
            .set(
                prescriptionId: prescriptionId,
                setIndex: setIndex,
                target: target,
                restAfterSec: restAfterSec
            ),
            at: index + 1
        )
        return next
    }
}
