import Foundation

public enum AIResponseMode: String, CaseIterable, Sendable {
    case jsonSchema
    case jsonObject
    case plain

    public var next: AIResponseMode? {
        switch self {
        case .jsonSchema: .jsonObject
        case .jsonObject: .plain
        case .plain: nil
        }
    }
}
