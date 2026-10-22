import Foundation

public enum PlanDraftParser {
    public static func draft(from text: String) -> PlanDraft? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("|"), let table = DraftTableAdapter.draft(from: trimmed) {
            return table
        }
        return DraftLineScanner.scan(trimmed)
    }

    public static func draft(fromJSON text: String) -> PlanDraft? {
        DraftJSONAdapter.draft(fromJSON: text)
    }
}
