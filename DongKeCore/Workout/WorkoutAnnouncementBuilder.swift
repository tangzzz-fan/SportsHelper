import Foundation

public struct WorkoutAnnouncementBuilder: Sendable {
    public struct Exercise: Equatable, Sendable {
        public var name: String
        public var totalSets: Int
        public var target: SetTarget
        public var catalogId: String
    }

    private let steps: [FlowStep]
    private let exercises: [String: Exercise]
    private let setCounts: [String: Int]
    private let dayTitle: String

    public init(plan: WorkoutPlan, dayIndex: Int) {
        let flow = WorkoutFlowModel(plan: plan, dayIndex: dayIndex)
        self.steps = flow.steps
        self.setCounts = flow.setCounts
        self.dayTitle = plan.days.first(where: { $0.dayIndex == dayIndex })?.title
            ?? plan.meta.title

        var collected: [String: Exercise] = [:]
        for day in plan.days where day.dayIndex == dayIndex {
            for block in day.blocks {
                for item in block.items {
                    collected[item.itemId] = Exercise(
                        name: item.name,
                        totalSets: max(1, item.sets),
                        target: item.target,
                        catalogId: item.catalogId
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

    public var exerciseCount: Int {
        setCounts.count
    }

    public func sessionStart() -> WorkoutAnnouncement {
        let sets = plannedSets
        return .sessionStart(
            title: sets > 0 ? dayTitle : "",
            exerciseCount: exerciseCount,
            totalSets: sets
        )
    }

    public func step(at index: Int) -> FlowStep? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    public func announcement(forStepAt index: Int) -> WorkoutAnnouncement? {
        guard steps.indices.contains(index) else { return nil }
        switch steps[index] {
        case let .set(prescriptionId, setIndex, target, _):
            guard let exercise = exercises[prescriptionId] else { return nil }
            let upcoming = nextExerciseName(after: index)
            return .setStart(
                name: exercise.name,
                setIndex: setIndex,
                totalSets: setCounts[prescriptionId] ?? exercise.totalSets,
                dose: Self.doseText(target),
                nextName: upcoming == exercise.name ? nil : upcoming
            )
        case .roundBreak, .blockBreak, .finished:
            return nil
        }
    }

    public func prompts(at index: Int, allowsEncouragement: Bool) -> [TimedPrompt] {
        guard steps.indices.contains(index),
              case let .set(prescriptionId, setIndex, target, _) = steps[index],
              let exercise = exercises[prescriptionId]
        else { return [] }
        let total = setCounts[prescriptionId] ?? exercise.totalSets
        return WorkoutPromptPlanner.prompts(
            target: target,
            cue: ExerciseLibrary.entry(for: exercise.catalogId)?.cues.first,
            isLastSet: setIndex >= total - 1,
            allowsEncouragement: allowsEncouragement
        )
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

    public func nextActionLabel(afterBlockBreakAt index: Int) -> String? {
        guard steps.indices.contains(index), case .blockBreak = steps[index] else { return nil }
        for step in steps.dropFirst(index + 1) {
            if case let .set(prescriptionId, _, target, _) = step,
               let exercise = exercises[prescriptionId] {
                return "\(exercise.name)，\(Self.doseText(target))"
            }
        }
        return nil
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
