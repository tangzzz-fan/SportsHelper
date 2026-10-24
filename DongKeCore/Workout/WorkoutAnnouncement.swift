import Foundation

public enum WorkoutAnnouncement: Equatable, Sendable {
    case sessionStart(title: String, exerciseCount: Int, totalSets: Int)
    case setStart(name: String, setIndex: Int, totalSets: Int, dose: String, nextName: String?)
    case restStart(seconds: Int)
    case restCountdown(secondsLeft: Int)
    case restFinished(nextName: String?, nextDose: String?)
    case blockBreak(seconds: Int, nextLabel: String)
    case finished(completedSets: Int, plannedSets: Int)

    public static let textLimit = 40

    public var text: String {
        switch self {
        case let .sessionStart(title, exerciseCount, totalSets):
            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.compose([
                ("开始训练", true),
                (name, true),
                (exerciseCount > 0 ? "\(exerciseCount) 个动作" : "", true),
                (totalSets > 0 ? "共 \(totalSets) 组" : "", false)
            ])
        case let .setStart(name, setIndex, totalSets, dose, nextName):
            return Self.compose([
                (name, true),
                ("第 \(setIndex) 组", true),
                ("共 \(totalSets) 组", false),
                (dose, true),
                (nextName.map { "下一个：\($0)" } ?? "", false)
            ])
        case let .restStart(seconds):
            return Self.compose([("休息", true), (Self.durationText(seconds), true)])
        case let .restCountdown(secondsLeft):
            return "\(secondsLeft)"
        case let .restFinished(nextName, nextDose):
            guard let nextName else {
                return Self.compose([("休息结束", true)])
            }
            return Self.compose([
                ("休息结束", true),
                ("下一个：\(nextName)", true),
                (nextDose ?? "", false)
            ])
        case let .blockBreak(seconds, nextLabel):
            let label = nextLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.compose([
                ("休息", true),
                (Self.durationText(seconds), true),
                (label.isEmpty ? "" : "接下来：\(label)", false)
            ])
        case let .finished(completedSets, plannedSets):
            let percent = plannedSets > 0
                ? Int((Double(completedSets) / Double(plannedSets) * 100).rounded())
                : 0
            return Self.compose([
                ("完成 \(completedSets) 组", true),
                ("完成率 \(min(100, max(0, percent)))%", false)
            ])
        }
    }

    public var isCountdown: Bool {
        if case .restCountdown = self { return true }
        return false
    }

    public static func durationText(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) 秒" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(rest) 秒"
    }

    private static func compose(_ parts: [(text: String, required: Bool)]) -> String {
        var kept = parts.filter { $0.text.isEmpty == false }
        while kept.reduce(0, { $0 + $1.text.count }) + max(0, kept.count - 1) > textLimit {
            guard let index = kept.lastIndex(where: { $0.required == false }) else { break }
            kept.remove(at: index)
        }
        let text = kept.map(\.text).joined(separator: "，")
        return text.count > textLimit ? String(text.prefix(textLimit)) : text
    }
}
