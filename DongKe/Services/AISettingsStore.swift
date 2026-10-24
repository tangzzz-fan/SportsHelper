import Foundation
import DongKeCore

@MainActor
@Observable
final class AISettingsStore {
    static let shared = AISettingsStore()

    private let defaults: UserDefaults
    private let secrets: SecretStoring
    private let keyAccount = "ai.apiKey"
    private let baseURLKey = "dk.ai.baseURL"
    private let modelKey = "dk.ai.model"

    var baseURL: String {
        didSet { defaults.set(baseURL, forKey: baseURLKey) }
    }

    var model: String {
        didSet { defaults.set(model, forKey: modelKey) }
    }

    private(set) var hasKey: Bool

    init(defaults: UserDefaults = .standard, secrets: SecretStoring = KeychainService()) {
        self.defaults = defaults
        self.secrets = secrets
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_SEED_AI"] == "1" {
            defaults.set("https://api.example.com/v1", forKey: "dk.ai.baseURL")
            defaults.set(AIConfiguration.defaultModel, forKey: "dk.ai.model")
            try? secrets.store("sk-preview-key", for: "ai.apiKey")
        }
        let environment = ProcessInfo.processInfo.environment
        if let base = environment["DK_AI_BASE_URL"], base.isEmpty == false {
            defaults.set(base, forKey: baseURLKey)
        }
        if let model = environment["DK_AI_MODEL"], model.isEmpty == false {
            defaults.set(model, forKey: modelKey)
        }
        if let key = environment["DK_AI_KEY"], key.isEmpty == false {
            try? secrets.store(key, for: keyAccount)
        }
        #endif
        self.baseURL = defaults.string(forKey: baseURLKey) ?? ""
        self.model = defaults.string(forKey: modelKey) ?? AIConfiguration.defaultModel
        self.hasKey = secrets.secret(for: keyAccount)?.isEmpty == false
    }

    var configuration: AIConfiguration {
        AIConfiguration(baseURL: baseURL, model: model, apiKey: secrets.secret(for: keyAccount))
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    func saveKey(_ raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        try secrets.store(trimmed.isEmpty ? nil : trimmed, for: keyAccount)
        hasKey = secrets.secret(for: keyAccount)?.isEmpty == false
    }

    func clearKey() {
        try? secrets.store(nil, for: keyAccount)
        hasKey = false
    }

    func reloadFromDisk() {
        baseURL = defaults.string(forKey: baseURLKey) ?? ""
        model = defaults.string(forKey: modelKey) ?? AIConfiguration.defaultModel
        hasKey = secrets.secret(for: keyAccount)?.isEmpty == false
    }
}
