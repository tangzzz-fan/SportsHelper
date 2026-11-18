import Foundation

@MainActor
public protocol AIPlanGenerating {
    func generatePlan(
        profile: UserProfile,
        brief: PlanBrief,
        memory: AliasMemory,
        exercises: UserExerciseCatalog,
        receiptSummary: String?
    ) async throws -> ParsedPlanDraft
}
