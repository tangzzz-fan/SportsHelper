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

    /// - Parameter includesFocus: 只有该动作的第一组才念要点。
    ///   一组一句「小腹收紧」重复三遍就是 Apple Workout Buddy 被骂的话痨；
    ///   首组详细、后续精简是 NTC 的做法（见 `.scratch/audio-audit/竞品与行业方案.md`）。
    public static func prompts(
        target: SetTarget,
        cue: String?,
        includesFocus: Bool = true
    ) -> [TimedPrompt] {
        guard target.type == .durationSec else { return [] }

        let total = target.value
        guard total >= shortestPromptedHold else { return [] }

        var planned: [TimedPrompt] = []
        if includesFocus,
           let cue,
           cue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            planned.append(TimedPrompt(atSecond: max(3, total / 3), prompt: .focus(cue)))
        }
        planned.append(TimedPrompt(atSecond: total - 3, prompt: .remaining(secondsLeft: 3)))
        return planned.sorted { $0.atSecond < $1.atSecond }
    }
}
