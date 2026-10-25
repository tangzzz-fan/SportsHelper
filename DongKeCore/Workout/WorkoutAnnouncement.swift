import Foundation

public enum WorkoutAnnouncement: Equatable, Sendable {
    case sessionStart(title: String, exerciseCount: Int, totalSets: Int)
    case setStart(name: String, setIndex: Int, totalSets: Int, dose: String)
    case restStart(seconds: Int)
    case restCountdown(secondsLeft: Int)
    case restFinished
    case blockBreak(seconds: Int, nextLabel: String)
    case finished(completedSets: Int, plannedSets: Int)
    case finishedWithExtras(completedSets: Int, plannedSets: Int, extraSets: Int)
    case setPrompt(WorkoutPrompt)

    public static let hardLimit = 32

    static let sessionBudget = 15
    static let setBudget = 20
    static let restBudget = 22
    static let breakBudget = 26
    static let finishBudget = 20
    static let extrasBudget = 26
    static let promptBudget = 12

    public var text: String {
        switch self {
        case let .sessionStart(title, exerciseCount, totalSets):
            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.compose([
                ("开始训练", true),
                (name, true),
                (totalSets > 0 ? "共 \(totalSets) 组" : "", false),
                (exerciseCount > 0 ? "\(exerciseCount) 个动作" : "", false)
            ], budget: Self.sessionBudget)
        case let .setStart(name, setIndex, totalSets, dose):
            return Self.compose([
                (name, true),
                ("第 \(setIndex) 组", true),
                ("共 \(totalSets) 组", false),
                (dose, true)
            ], budget: Self.setBudget)
        case let .restStart(seconds):
            return Self.compose([("休息", true), (Self.durationText(seconds), true)], budget: Self.restBudget)
        case let .restCountdown(secondsLeft):
            return "\(secondsLeft)"
        case .restFinished:
            return "休息结束"
        case let .blockBreak(seconds, nextLabel):
            let label = nextLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.compose([
                ("休息", true),
                (Self.durationText(seconds), true),
                (label.isEmpty ? "" : "接下来：\(label)", false)
            ], budget: Self.breakBudget)
        case let .setPrompt(prompt):
            switch prompt {
            case let .focus(cue):
                return cue
            case let .remaining(secondsLeft):
                return "\(secondsLeft)"
            }
        case let .finished(completedSets, plannedSets):
            return Self.compose([
                ("完成 \(completedSets) 组", true),
                ("完成率 \(Self.percent(completedSets, plannedSets))%", false)
            ], budget: Self.finishBudget)
        case let .finishedWithExtras(completedSets, plannedSets, extraSets):
            return Self.compose([
                ("完成 \(completedSets) 组", true),
                ("完成率 \(Self.percent(completedSets, plannedSets))%", false),
                ("另有 \(extraSets) 组加练", false)
            ], budget: Self.extrasBudget)
        }
    }

    public var isCountdown: Bool {
        if case .restCountdown = self { return true }
        return false
    }

    public var priority: SpeechPriority {
        switch self {
        case .sessionStart, .setStart, .finished, .finishedWithExtras,
             .restCountdown, .setPrompt(.remaining):
            return .instruction
        case .restStart, .restFinished, .blockBreak, .setPrompt(.focus):
            return .aside
        }
    }

    public static func durationText(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) 秒" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(rest) 秒"
    }

    private static func percent(_ completed: Int, _ planned: Int) -> Int {
        guard planned > 0 else { return 0 }
        let value = Int((Double(completed) / Double(planned) * 100).rounded())
        return min(100, max(0, value))
    }

    private static func compose(_ parts: [(text: String, required: Bool)], budget: Int) -> String {
        var kept = parts.filter { $0.text.isEmpty == false }
        while kept.reduce(0, { $0 + $1.text.count }) + max(0, kept.count - 1) > budget {
            guard let index = kept.lastIndex(where: { $0.required == false }) else { break }
            kept.remove(at: index)
        }
        let text = kept.map(\.text).joined(separator: "，")
        return text.count > hardLimit ? String(text.prefix(hardLimit)) : text
    }
}
