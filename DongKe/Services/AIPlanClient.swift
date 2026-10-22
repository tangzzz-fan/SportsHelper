import Foundation
import DongKeCore

@MainActor
final class AIPlanClient: AIPlanGenerating {
    private enum SendOutcome {
        case content(String)
        case degrade
    }

    private let settings: AISettingsStore
    private let session: URLSession

    init(settings: AISettingsStore = .shared, session: URLSession = AIPlanClient.makeSession()) {
        self.settings = settings
        self.session = session
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    func generatePlan(profile: UserProfile, extraNote: String) async throws -> ParsedPlanDraft {
        let configuration = settings.configuration
        guard let key = configuration.resolvedKey else { throw AIClientError.missingKey }
        let url = try AIEndpoint.completionsURL(baseURL: configuration.trimmedBaseURL).get()
        let messages = AIPromptBuilder.makeMessages(profile: profile, extraNote: extraNote)

        var mode: AIResponseMode? = .jsonSchema
        while let current = mode {
            let outcome = try await attempt(
                url: url,
                key: key,
                model: configuration.resolvedModel,
                messages: messages,
                mode: current
            )
            switch outcome {
            case let .content(text):
                return try AIPlanInterpreter.interpret(text).get()
            case .degrade:
                mode = current.next
            }
        }
        throw AIClientError.serverError(400)
    }

    private func attempt(
        url: URL,
        key: String,
        model: String,
        messages: [ChatMessage],
        mode: AIResponseMode
    ) async throws -> SendOutcome {
        do {
            return try await send(url: url, key: key, model: model, messages: messages, mode: mode)
        } catch let error as AIClientError where error.isRetryable {
            try await Task.sleep(for: .seconds(2))
            return try await send(url: url, key: key, model: model, messages: messages, mode: mode)
        }
    }

    private func send(
        url: URL,
        key: String,
        model: String,
        messages: [ChatMessage],
        mode: AIResponseMode
    ) async throws -> SendOutcome {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = ChatRequestBodyBuilder.data(model: model, messages: messages, mode: mode)

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch AIResponseMapper.outcome(status: status, body: data) {
            case let .content(text):
                return .content(text)
            case .degrade:
                return .degrade
            case let .failure(error):
                throw error
            }
        } catch let error as URLError {
            throw AIResponseMapper.transportError(error)
        }
    }
}
