import Foundation

@MainActor
public protocol AIPlanGenerating {
    func generatePlan(
        profile: UserProfile,
        brief: PlanBrief,
        memory: AliasMemory,
        exercises: UserExerciseCatalog
    ) async throws -> ParsedPlanDraft
}

public extension AIPlanGenerating {
    func generatePlan(profile: UserProfile, brief: PlanBrief) async throws -> ParsedPlanDraft {
        try await generatePlan(profile: profile, brief: brief, memory: .empty, exercises: .empty)
    }

    func generatePlan(profile: UserProfile, extraNote: String) async throws -> ParsedPlanDraft {
        try await generatePlan(
            profile: profile,
            brief: PlanBriefParser.parse(extraNote),
            memory: .empty,
            exercises: .empty
        )
    }
}
