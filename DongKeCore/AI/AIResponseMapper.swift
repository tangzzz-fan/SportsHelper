import Foundation

public enum AIHTTPOutcome: Equatable, Sendable {
    case content(String)
    case degrade
    case failure(AIClientError)
}

public enum AIResponseMapper {
    public static func outcome(status: Int, body: Data) -> AIHTTPOutcome {
        switch status {
        case 200..<300:
            return content(from: body)
        case 400:
            return degradeRequested(in: body) ? .degrade : .failure(.serverError(400))
        case 401, 403:
            return .failure(.unauthorized)
        case 429:
            return .failure(.rateLimited)
        default:
            return .failure(.serverError(status))
        }
    }

    public static func transportError(_ error: URLError) -> AIClientError {
        error.code == .timedOut ? .timeout : .transport("URLError \(error.code.rawValue)")
    }

    private static func content(from body: Data) -> AIHTTPOutcome {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String
        else {
            return .failure(.invalidJSON)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .failure(.emptyResponse) : .content(trimmed)
    }

    private static func degradeRequested(in body: Data) -> Bool {
        let text = String(decoding: body, as: UTF8.self).lowercased()
        return text.contains("response_format")
            || text.contains("json_schema")
            || text.contains("not supported")
    }
}
