import Foundation

public enum FreeTextPlanParser {
    public static func parse(
        _ text: String,
        memory: AliasMemory = .empty,
        exercises: UserExerciseCatalog = .empty
    ) -> ParsedPlanDraft {
        guard let draft = PlanDraftParser.draft(from: text, memory: memory) else {
            return ParsedPlanDraft.empty(rawText: text)
        }
        let compiled = PlanDraftCompiler.compile(draft, exercises: exercises)
        return ParsedPlanDraft(
            plan: compiled.plan,
            issues: PlanValidator.validate(compiled.plan),
            rawText: text,
            path: .freeText,
            assumptions: compiled.assumptions,
            unmappedNames: compiled.unmappedNames,
            guessedItems: compiled.guessedItems
        )
    }
}
