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
    private let basePlannedSets: Int

    public init(plan: WorkoutPlan, dayIndex: Int, steps: [FlowStep]? = nil) {
        let flow = WorkoutFlowModel(plan: plan, dayIndex: dayIndex)
        self.steps = steps ?? flow.steps
        self.setCounts = flow.setCounts
        self.basePlannedSets = flow.plannedSets

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
        basePlannedSets
    }

    public var exerciseCount: Int {
        setCounts.count
    }

    public func sessionStart() -> WorkoutAnnouncement {
        .sessionStart(exerciseCount: exerciseCount, totalSets: plannedSets)
    }

    public func step(at index: Int) -> FlowStep? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    public func announcement(forStepAt index: Int) -> WorkoutAnnouncement? {
        guard steps.indices.contains(index) else { return nil }
        switch steps[index] {
        case let .set(prescriptionId, setIndex, target, _):
            guard let exercise = exercises[prescriptionId] else { return nil }
            let total = max(setCounts[prescriptionId] ?? exercise.totalSets, setIndex)
            return .setStart(
                name: exercise.name,
                setIndex: setIndex,
                totalSets: total,
                dose: Self.doseText(target)
            )
        case .roundBreak, .blockBreak, .finished:
            return nil
        }
    }

    public func prompts(at index: Int) -> [TimedPrompt] {
        guard steps.indices.contains(index),
              case let .set(prescriptionId, setIndex, target, _) = steps[index],
              let exercise = exercises[prescriptionId]
        else { return [] }
        return WorkoutPromptPlanner.prompts(
            target: target,
            cue: ExerciseLibrary.entry(for: exercise.catalogId)?.cues.first,
            includesFocus: setIndex == 1
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

    public func restFinished(nextStepIndex: Int?) -> WorkoutAnnouncement? {
        guard let nextStepIndex,
              steps.indices.contains(nextStepIndex),
              case .set = steps[nextStepIndex]
        else { return .restFinished }
        return nil
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

    public func finished(completedSets: Int, extraSets: Int = 0) -> WorkoutAnnouncement {
        if extraSets > 0 {
            return .finishedWithExtras(
                completedSets: completedSets,
                plannedSets: plannedSets,
                extraSets: extraSets
            )
        }
        return .finished(completedSets: completedSets, plannedSets: plannedSets)
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
