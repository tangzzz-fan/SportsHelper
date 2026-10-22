import Foundation

public enum PlanDecodeError: Error, Equatable {
    case emptyInput
    case tooLarge
    case noJSONObject
    case schemaMismatch([ParseIssue])
}

public enum PlanDecoder {
    public static func decode(_ json: String) throws -> WorkoutPlan {
        throw PlanDecodeError.noJSONObject
    }

    public static func decodeLenient(_ json: String) throws -> (plan: WorkoutPlan, issues: [ParseIssue]) {
        throw PlanDecodeError.noJSONObject
    }
}
