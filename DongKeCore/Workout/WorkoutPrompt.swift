import Foundation

public enum WorkoutPrompt: Equatable, Sendable {
    case focus(String)
    case remaining(secondsLeft: Int)
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

    public static func prompts(target: SetTarget, cue: String?) -> [TimedPrompt] {
        guard target.type == .durationSec else { return [] }

        let total = target.value
        guard total >= shortestPromptedHold else { return [] }

        var planned: [TimedPrompt] = []
        if let cue, cue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            planned.append(TimedPrompt(atSecond: max(3, total / 3), prompt: .focus(cue)))
        }
        planned.append(TimedPrompt(atSecond: total - 3, prompt: .remaining(secondsLeft: 3)))
        return planned.sorted { $0.atSecond < $1.atSecond }
    }
}
