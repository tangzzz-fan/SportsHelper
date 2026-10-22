import Foundation

public struct AIConfiguration: Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var apiKey: String?

    public static let defaultModel = "gpt-4o-mini"

    public init(baseURL: String = "", model: String = AIConfiguration.defaultModel, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
    }

    public var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var resolvedModel: String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AIConfiguration.defaultModel : trimmed
    }

    public var resolvedKey: String? {
        guard let apiKey else { return nil }
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var isConfigured: Bool {
        trimmedBaseURL.isEmpty == false && resolvedKey != nil
    }
}
