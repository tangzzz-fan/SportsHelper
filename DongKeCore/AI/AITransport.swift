import Foundation

public struct AITransport: Sendable {
    public struct Request: Sendable {
        public var url: URL
        public var key: String
        public var model: String
        public var messages: [ChatMessage]

        public init(url: URL, key: String, model: String, messages: [ChatMessage]) {
            self.url = url
            self.key = key
            self.model = model
            self.messages = messages
        }
    }

    public struct Response: Sendable {
        public var status: Int
        public var body: Data

        public init(status: Int, body: Data) {
            self.status = status
            self.body = body
        }
    }

    public struct Result: Equatable, Sendable {
        public var text: String
        public var mode: AIResponseMode

        public init(text: String, mode: AIResponseMode) {
            self.text = text
            self.mode = mode
        }
    }

    public typealias Sender = @Sendable (URLRequest) async throws -> Response
    public typealias Sleeper = @Sendable (Duration) async throws -> Void

    private let retryDelay: Duration
    private let sleep: Sleeper
    private let sender: Sender

    public init(
        retryDelay: Duration = .seconds(2),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        sender: @escaping Sender
    ) {
        self.retryDelay = retryDelay
        self.sleep = sleep
        self.sender = sender
    }

    public static func live(session: URLSession = makeSession()) -> AITransport {
        AITransport(sender: { request in
            let (data, response) = try await session.data(for: request)
            return Response(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
        })
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    public func generate(_ request: Request, startingAt initial: AIResponseMode = .jsonSchema) async throws -> Result {
        var mode: AIResponseMode? = initial
        var lastRejection = ""
        while let current = mode {
            switch try await attempt(request, mode: current) {
            case let .content(text):
                return Result(text: text, mode: current)
            case let .formatRejected(snippet):
                lastRejection = snippet
                mode = current.next
            }
        }
        throw AIClientError.requestRejected(400, lastRejection)
    }

    public static func urlRequest(_ request: Request, mode: AIResponseMode) -> URLRequest {
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
        return urlRequest
    }

    private enum Outcome {
        case content(String)
        case formatRejected(String)
    }

    private func attempt(_ request: Request, mode: AIResponseMode) async throws -> Outcome {
        do {
            return try await send(request, mode: mode)
        } catch let error as AIClientError where error.isRetryable {
            try await sleep(retryDelay)
            return try await send(request, mode: mode)
        }
    }

    private func send(_ request: Request, mode: AIResponseMode) async throws -> Outcome {
        do {
            let response = try await sender(Self.urlRequest(request, mode: mode))
            switch AIResponseMapper.outcome(status: response.status, body: response.body) {
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
