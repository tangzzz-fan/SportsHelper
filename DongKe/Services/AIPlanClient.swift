import Foundation
import DongKeCore

@MainActor
final class AIPlanClient: AIPlanGenerating {
    private enum SendOutcome {
        case content(String)
        case formatRejected(String)
    }

    private struct Request {
        let url: URL
        let key: String
        let model: String
        let messages: [ChatMessage]
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
        let request = Request(
            url: try AIEndpoint.completionsURL(baseURL: configuration.trimmedBaseURL).get(),
            key: key,
            model: configuration.resolvedModel,
            messages: AIPromptBuilder.makeMessages(profile: profile, extraNote: extraNote)
        )

        var mode: AIResponseMode? = .jsonSchema
        var lastRejection = ""
        while let current = mode {
            switch try await attempt(request, mode: current) {
            case let .content(text):
                return try AIPlanInterpreter.interpret(text).get()
            case let .formatRejected(snippet):
                lastRejection = snippet
                mode = current.next
            }
        }
        throw AIClientError.requestRejected(400, lastRejection)
    }

    private func attempt(_ request: Request, mode: AIResponseMode) async throws -> SendOutcome {
        do {
            return try await send(request, mode: mode)
        } catch let error as AIClientError where error.isRetryable {
            try await Task.sleep(for: .seconds(2))
            return try await send(request, mode: mode)
        }
    }

    private func send(_ request: Request, mode: AIResponseMode) async throws -> SendOutcome {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(request.key)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = ChatRequestBodyBuilder.data(
            model: request.model,
            messages: request.messages,
            mode: mode
        )

        do {
            let (data, response) = try await session.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch AIResponseMapper.outcome(status: status, body: data) {
            case let .content(text):
                return .content(text)
            case let .degrade(snippet):
                return .formatRejected(snippet)
            case let .failure(error):
                throw error
            }
        } catch let error as URLError {
            throw AIResponseMapper.transportError(error)
        }
    }
}
