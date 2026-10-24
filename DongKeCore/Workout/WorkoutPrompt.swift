import Foundation

public enum WorkoutPrompt: Equatable, Sendable {
    case focus(String)
    case remaining(secondsLeft: Int)
    case encourage(secondsLeft: Int)
}

public struct TimedPrompt: Equatable, Sendable {
    public let atSecond: Int
    public let prompt: WorkoutPrompt

    public init(atSecond: Int, prompt: WorkoutPrompt) {
        self.atSecond = atSecond
        self.prompt = prompt
    }
}

public enum WorkoutPromptPlanner {
    public static let shortestPromptedHold = 12

    public static func prompts(
        target: SetTarget,
        cue: String?,
        isLastSet: Bool,
        allowsEncouragement: Bool
    ) -> [TimedPrompt] {
        guard target.type == .durationSec, target.value >= shortestPromptedHold else { return [] }

        let total = target.value
        var planned: [TimedPrompt] = []

        if let cue, cue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            planned.append(TimedPrompt(atSecond: max(3, total / 3), prompt: .focus(cue)))
        }

        planned.append(TimedPrompt(atSecond: total - 3, prompt: .remaining(secondsLeft: 3)))

        if isLastSet, allowsEncouragement {
            let at = total - 5
            if planned.allSatisfy({ abs($0.atSecond - at) >= 2 }) {
                planned.append(TimedPrompt(atSecond: at, prompt: .encourage(secondsLeft: 5)))
            }
        }

        return planned.sorted { $0.atSecond < $1.atSecond }
    }
}
