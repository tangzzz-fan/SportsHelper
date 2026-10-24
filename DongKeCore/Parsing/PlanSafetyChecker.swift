import Foundation

public struct SafetyIssue: Equatable, Sendable, Identifiable {
    public var dayIndex: Int
    public var itemId: String
    public var exerciseName: String
    public var parts: [BodyPart]
    public var alternativeName: String?
    public var regressionName: String?

    public var id: String { "\(dayIndex)-\(itemId)" }

    public init(
        dayIndex: Int,
        itemId: String,
        exerciseName: String,
        parts: [BodyPart],
        alternativeName: String? = nil,
        regressionName: String? = nil
    ) {
        self.dayIndex = dayIndex
        self.itemId = itemId
        self.exerciseName = exerciseName
        self.parts = parts
        self.alternativeName = alternativeName
        self.regressionName = regressionName
    }

    public var partText: String {
        parts.map(\.chineseName).joined(separator: "、")
    }

    public var remedy: Remedy {
        if let alternativeName { return .alternative(alternativeName) }
        if let regressionName { return .regression(regressionName) }
        return .reduce
    }

    public enum Remedy: Equatable, Sendable {
        case alternative(String)
        case regression(String)
        case reduce
    }
}

public enum PlanSafetyChecker {
    public static let disclaimer = "计划不替代医疗建议。疼痛加重，或出现手臂麻木、头晕，请就医。"

    public static func check(_ plan: WorkoutPlan, soreParts: Set<BodyPart>) -> [SafetyIssue] {
        check(plan.days, soreParts: soreParts)
    }

    public static func check(_ day: PlanDay, soreParts: Set<BodyPart>) -> [SafetyIssue] {
        check([day], soreParts: soreParts)
    }

    private static func check(_ days: [PlanDay], soreParts: Set<BodyPart>) -> [SafetyIssue] {
        guard soreParts.isEmpty == false else { return [] }

        var issues: [SafetyIssue] = []
        for day in days where day.isRestDay == false {
            for block in day.blocks {
                for item in block.items {
                    guard let entry = ExerciseLibrary.entry(for: item.catalogId) else { continue }
                    let hit = entry.affectedParts.intersection(soreParts)
                    guard hit.isEmpty == false else { continue }

                    let alternative = alternative(for: entry, avoiding: soreParts)
                    issues.append(SafetyIssue(
                        dayIndex: day.dayIndex,
                        itemId: item.itemId,
                        exerciseName: entry.name,
                        parts: BodyPart.allCases.filter { hit.contains($0) },
                        alternativeName: alternative,
                        regressionName: alternative == nil ? lighter(entry) : nil
                    ))
                }
            }
        }
        return issues
    }

    public static func issues(
        _ issues: [SafetyIssue],
        inDay dayIndex: Int
    ) -> [SafetyIssue] {
        issues.filter { $0.dayIndex == dayIndex }
    }

    public static func reliefs(for soreParts: Set<BodyPart>) -> [ExerciseEntry] {
        guard soreParts.isEmpty == false else { return [] }
        return ExerciseLibrary.all.filter { entry in
            entry.relievedParts.isDisjoint(with: soreParts) == false
                && entry.affectedParts.isDisjoint(with: soreParts)
        }
    }

    private static func alternative(
        for entry: ExerciseEntry,
        avoiding soreParts: Set<BodyPart>
    ) -> String? {
        guard let id = entry.alternativeId,
              id != entry.id,
              let target = ExerciseLibrary.entry(for: id),
              target.affectedParts.isDisjoint(with: soreParts)
        else { return nil }
        return target.name
    }

    private static func lighter(_ entry: ExerciseEntry) -> String? {
        let name = entry.regressionName.trimmingCharacters(in: .whitespaces)
        guard name.isEmpty == false, name != entry.name else { return nil }
        return name
    }
}
