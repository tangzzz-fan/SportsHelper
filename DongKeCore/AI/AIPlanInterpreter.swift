import Foundation

public enum AIPlanInterpreter {
    private static let maxBytes = 64 * 1024

    public static func interpret(
        _ content: String,
        memory: AliasMemory = .empty,
        exercises: UserExerciseCatalog = .empty
    ) -> Result<ParsedPlanDraft, AIClientError> {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return .failure(.emptyResponse) }
        guard trimmed.utf8.count <= maxBytes else {
            return .failure(.schemaMismatch("返回内容超过 64KB"))
        }
        guard PlanJSONExtractor.extract(from: trimmed) != nil else {
            return .failure(.invalidJSON)
        }

        let draft = PlanImportService.parse(trimmed, memory: memory, exercises: exercises)
        guard let plan = draft.plan else {
            let detail = draft.issues.first(where: { $0.severity == .error })?.message ?? "结构不符合计划契约"
            return .failure(.schemaMismatch(detail))
        }
        guard draft.path == .strictJSON || draft.path == .lenientJSON else {
            return .failure(.invalidJSON)
        }
        if let blocking = PlanValidator.validate(plan).first(where: { $0.severity == .error }) {
            return .failure(.schemaMismatch(blocking.message))
        }
        return .success(draft)
    }
}
