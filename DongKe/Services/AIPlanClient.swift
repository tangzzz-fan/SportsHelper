import Foundation
import DongKeCore

@MainActor
final class AIPlanClient: AIPlanGenerating {
    private let settings: AISettingsStore
    private let transport: AITransport

    init(settings: AISettingsStore = .shared, transport: AITransport = .live()) {
        self.settings = settings
        self.transport = transport
    }

    func generatePlan(
        profile: UserProfile,
        brief: PlanBrief,
        memory: AliasMemory,
        exercises: UserExerciseCatalog
    ) async throws -> ParsedPlanDraft {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_AI_FAKE"] == "1" {
            let plan = PlanGenerator.makePlan(profile: profile)
            let data = try JSONEncoder().encode(plan)
            return try AIPlanInterpreter
                .interpret(String(decoding: data, as: UTF8.self), memory: memory, exercises: exercises)
                .get()
        }
        #endif

        let configuration = settings.configuration
        guard let key = configuration.resolvedKey else { throw AIClientError.missingKey }
        let request = AITransport.Request(
            url: try AIEndpoint.completionsURL(baseURL: configuration.trimmedBaseURL).get(),
            key: key,
            model: configuration.resolvedModel,
            messages: AIPromptBuilder.makeMessages(profile: profile, brief: brief)
        )
        let result = try await transport.generate(request)
        return try AIPlanInterpreter.interpret(result.text, memory: memory, exercises: exercises).get()
    }
}
