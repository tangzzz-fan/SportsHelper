import Foundation

/// 新旧两版计划的差异。只列事实，不评价好坏——「换掉了深蹲」是好是坏，
/// 取决于用户为什么换，App 不知道。
public struct PlanDiff: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case added
        case removed
        case changed
    }

    public struct Line: Equatable, Sendable, Identifiable {
        public var id: String
        public var kind: Kind
        public var day: String
        public var text: String

        public init(id: String, kind: Kind, day: String, text: String) {
            self.id = id
            self.kind = kind
            self.day = day
            self.text = text
        }
    }

    public var lines: [Line]
    /// 新计划里出现、而且用户之前标过疼的动作名。
    public var painful: [String]

    public init(lines: [Line] = [], painful: [String] = []) {
        self.lines = lines
        self.painful = painful
    }

    public var isEmpty: Bool { lines.isEmpty && painful.isEmpty }

    public static func compare(
        old: WorkoutPlan,
        new: WorkoutPlan,
        painCatalogIds: Set<String> = []
    ) -> PlanDiff {
        var lines: [Line] = []
        var painful: [String] = []

        for day in 1...7 {
            let oldDay = old.days.first { $0.dayIndex == day }
            let newDay = new.days.first { $0.dayIndex == day }
            let oldItems = keyed(oldDay)
            let newItems = keyed(newDay)
            let dayName = newDay?.title ?? oldDay?.title ?? "第 \(day) 天"

            for (catalogId, item) in newItems.sorted(by: { $0.key < $1.key }) where oldItems[catalogId] == nil {
                lines.append(Line(
                    id: "add-\(day)-\(catalogId)",
                    kind: .added,
                    day: dayName,
                    text: "新增 \(item.name) \(summary(item))"
                ))
            }

            for (catalogId, item) in oldItems.sorted(by: { $0.key < $1.key }) where newItems[catalogId] == nil {
                lines.append(Line(
                    id: "drop-\(day)-\(catalogId)",
                    kind: .removed,
                    day: dayName,
                    text: "换下 \(item.name)"
                ))
            }

            for (catalogId, oldItem) in oldItems.sorted(by: { $0.key < $1.key }) {
                guard let newItem = newItems[catalogId] else { continue }
                guard let text = changeText(from: oldItem, to: newItem) else { continue }
                lines.append(Line(
                    id: "change-\(day)-\(catalogId)",
                    kind: .changed,
                    day: dayName,
                    text: "\(newItem.name) \(text)"
                ))
            }
        }

        for day in new.days {
            for item in day.blocks.flatMap(\.items) where painCatalogIds.contains(item.catalogId) {
                if painful.contains(item.name) == false { painful.append(item.name) }
            }
        }

        return PlanDiff(lines: lines, painful: painful)
    }

    private static func keyed(_ day: PlanDay?) -> [String: ExercisePrescription] {
        guard let day else { return [:] }
        return Dictionary(
            day.blocks.flatMap(\.items).map { ($0.catalogId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func summary(_ item: ExercisePrescription) -> String {
        "\(item.sets) 组 × \(item.target.doseText)"
    }

    private static func changeText(from old: ExercisePrescription, to new: ExercisePrescription) -> String? {
        var parts: [String] = []
        if old.sets != new.sets {
            parts.append("\(old.sets) 组 → \(new.sets) 组")
        }
        if old.target.value != new.target.value || old.target.type != new.target.type {
            parts.append("\(old.target.doseText) → \(new.target.doseText)")
        }
        if abs(old.load.value - new.load.value) > 0.001 || old.load.type != new.load.type {
            parts.append("\(old.load.shortText ?? "自重") → \(new.load.shortText ?? "自重")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "，")
    }
}
