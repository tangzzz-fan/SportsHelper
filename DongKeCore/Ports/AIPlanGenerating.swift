import Foundation

@MainActor
public protocol AIPlanGenerating {
    func generatePlan(profile: UserProfile, extraNote: String) async throws -> ParsedPlanDraft
}

public protocol SecretStoring: Sendable {
    func secret(for account: String) -> String?
    func store(_ secret: String?, for account: String) throws
}
