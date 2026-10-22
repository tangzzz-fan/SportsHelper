import Foundation

public enum PlanNormalizer {
    public static func normalize(_ plan: WorkoutPlan) -> (plan: WorkoutPlan, issues: [ParseIssue]) {
        (plan, [])
    }
}
