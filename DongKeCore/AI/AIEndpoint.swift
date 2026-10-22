import Foundation

public enum AIEndpoint {
    public static func completionsURL(baseURL: String) -> Result<URL, AIClientError> {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("https://"),
              var components = URLComponents(string: trimmed),
              let host = components.host,
              !host.isEmpty
        else {
            return .failure(.invalidBaseURL)
        }

        components.query = nil
        components.fragment = nil

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.lowercased().hasSuffix("/chat/completions") == false {
            path += "/chat/completions"
        }
        components.path = path

        guard let url = components.url else {
            return .failure(.invalidBaseURL)
        }
        return .success(url)
    }
}
