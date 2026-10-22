import Foundation

public enum PlanNormalizer {
    public static func normalize(_ plan: WorkoutPlan) -> (plan: WorkoutPlan, issues: [ParseIssue]) {
        var normalized = plan
        var issues: [ParseIssue] = []

        normalized.days.sort { $0.dayIndex < $1.dayIndex }

        for index in normalized.days.indices {
            guard normalized.days[index].isRestDay else { continue }
            if !normalized.days[index].blocks.isEmpty {
                normalized.days[index].blocks = []
                issues.append(ParseIssue(
                    path: "days[\(index)].blocks",
                    severity: .warning,
                    message: "休息日的训练区块已清空"
                ))
            }
            normalized.days[index].estimatedMinutes = 0
        }

        let trainingDays = normalized.days.filter { !$0.isRestDay }.count
        if trainingDays > 0, normalized.meta.daysPerWeek != trainingDays {
            normalized.meta.daysPerWeek = trainingDays
            issues.append(ParseIssue(
                path: "meta.daysPerWeek",
                severity: .warning,
                message: "每周训练天数已按训练日重算"
            ))
        }

        return (normalized, issues)
    }
}
