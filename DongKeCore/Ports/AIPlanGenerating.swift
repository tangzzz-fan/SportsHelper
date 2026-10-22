import Foundation

@MainActor
public protocol AIPlanGenerating {
    func generatePlan(profile: UserProfile, extraNote: String) async throws -> ParsedPlanDraft
}
