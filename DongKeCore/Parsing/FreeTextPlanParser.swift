import Foundation

public enum FreeTextPlanParser {
    public static func parse(_ text: String) -> ParsedPlanDraft {
        ParsedPlanDraft.empty(rawText: text)
    }
}
