import Foundation

public enum FreeTextPlanParser {
    public static func parse(_ text: String) -> ParsedPlanDraft {
        guard let draft = PlanDraftParser.draft(from: text) else {
            return ParsedPlanDraft.empty(rawText: text)
        }
        let compiled = PlanDraftCompiler.compile(draft)
        return ParsedPlanDraft(
            plan: compiled.plan,
            issues: PlanValidator.validate(compiled.plan),
            rawText: text,
            path: .freeText,
            assumptions: compiled.assumptions,
            unmappedNames: compiled.unmappedNames
        )
    }
}
