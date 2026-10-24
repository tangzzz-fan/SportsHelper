import Foundation

public enum AIDefaults {
    public static let baseURL: String = payload["baseURL"] ?? ""
    public static let model: String = payload["model"] ?? ""
    public static var hasBuiltInKey: Bool { (payload["apiKey"] ?? "").isEmpty == false }
    public static var apiKey: String { payload["apiKey"] ?? "" }

    private static let payload: [String: String] = {
        guard let url = Bundle.main.url(forResource: "ai-defaults", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }()
}
