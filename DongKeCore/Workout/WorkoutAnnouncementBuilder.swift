import Foundation

public struct WorkoutAnnouncementBuilder: Sendable {
    public struct Exercise: Equatable, Sendable {
        public var name: String
        public var totalSets: Int
        public var target: SetTarget
    }

    private let steps: [FlowStep]
    private let exercises: [String: Exercise]
    private let title: String

    public init(plan: WorkoutPlan, dayIndex: Int) {
        self.steps = WorkoutFlowModel(plan: plan, dayIndex: dayIndex).steps
        self.title = plan.meta.title

        var collected: [String: Exercise] = [:]
        for day in plan.days where day.dayIndex == dayIndex {
            for block in day.blocks {
                for item in block.items {
                    collected[item.itemId] = Exercise(
                        name: item.name,
                        totalSets: max(1, item.sets),
                        target: item.target
                    )
                }
            }
        }
        self.exercises = collected
    }

    public var plannedSets: Int {
        steps.reduce(into: 0) { count, step in
            if case .set = step { count += 1 }
        }
    }

    public func sessionStart() -> WorkoutAnnouncement {
        .sessionStart(title: title, totalSets: plannedSets)
    }

    public func announcement(forStepAt index: Int) -> WorkoutAnnouncement? {
        guard steps.indices.contains(index) else { return nil }
        switch steps[index] {
        case let .set(prescriptionId, setIndex, target, _):
            guard let exercise = exercises[prescriptionId] else { return nil }
            return .setStart(
                name: exercise.name,
                setIndex: setIndex,
                totalSets: exercise.totalSets,
                dose: Self.doseText(target),
                nextName: nextExerciseName(after: index)
            )
        case let .roundBreak(seconds):
            return restStart(seconds: seconds)
        case let .blockBreak(seconds, nextBlockTitle):
            guard seconds > 0 else { return nil }
            return .blockBreak(seconds: seconds, nextBlockTitle: nextBlockTitle)
        case .finished:
            return nil
        }
    }

    public func restStart(seconds: Int) -> WorkoutAnnouncement? {
        guard seconds > 0 else { return nil }
        return .restStart(seconds: seconds)
    }

    public func countdown(secondsLeft: Int) -> WorkoutAnnouncement? {
        guard (1...3).contains(secondsLeft) else { return nil }
        return .restCountdown(secondsLeft: secondsLeft)
    }

    public func restFinished(nextStepIndex: Int?) -> WorkoutAnnouncement {
        guard let nextStepIndex,
              steps.indices.contains(nextStepIndex),
              case let .set(prescriptionId, _, target, _) = steps[nextStepIndex],
              let exercise = exercises[prescriptionId]
        else {
            return .restFinished(nextName: nil, nextDose: nil)
        }
        return .restFinished(nextName: exercise.name, nextDose: Self.doseText(target))
    }

    public func finished(completedSets: Int) -> WorkoutAnnouncement {
        .finished(completedSets: completedSets, plannedSets: plannedSets)
    }

    private func nextExerciseName(after index: Int) -> String? {
        for step in steps.dropFirst(index + 1) {
            if case let .set(prescriptionId, _, _, _) = step {
                return exercises[prescriptionId]?.name
            }
        }
        return nil
    }

    public static func doseText(_ target: SetTarget) -> String {
        let value = target.perSide ? "每侧 \(target.value)" : "\(target.value)"
        switch target.type {
        case .reps:
            return "\(value) 次"
        case .durationSec:
            return "\(value) 秒"
        case .distanceM:
            guard target.value >= 1000 else { return "\(value) 米" }
            let kilometers = Double(target.value) / 1000
            let text = kilometers == kilometers.rounded()
                ? "\(Int(kilometers))"
                : String(format: "%.1f", kilometers)
            return target.perSide ? "每侧 \(text) 公里" : "\(text) 公里"
        }
    }
}
