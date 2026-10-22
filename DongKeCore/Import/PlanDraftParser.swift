import Foundation

public enum PlanDraftParser {
    public static func draft(from text: String, memory: AliasMemory = .empty) -> PlanDraft? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("|"), let table = DraftTableAdapter.draft(from: trimmed, memory: memory) {
            return table
        }
        return DraftLineScanner.scan(trimmed, memory: memory)
    }

    public static func draft(fromJSON text: String, memory: AliasMemory = .empty) -> PlanDraft? {
        DraftJSONAdapter.draft(fromJSON: text, memory: memory)
    }
}
