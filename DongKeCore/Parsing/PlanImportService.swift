import Foundation

public enum PlanImportService {
    private static let maxBytes = 64 * 1024

    public static func parse(
        _ text: String,
        memory: AliasMemory = .empty,
        exercises: UserExerciseCatalog = .empty
    ) -> ParsedPlanDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedPlanDraft(
                plan: nil,
                issues: [ParseIssue(path: "root", severity: .error, message: "先粘贴一段计划内容，或者手动添加动作")],
                rawText: text,
                path: .blank
            )
        }
        guard trimmed.utf8.count <= maxBytes else {
            return ParsedPlanDraft(
                plan: nil,
                issues: [ParseIssue(path: "root", severity: .error, message: "内容超过 64KB，请只粘贴计划本身")],
                rawText: text,
                path: .blank
            )
        }

        if let extracted = PlanJSONExtractor.extract(from: trimmed) {
            if let plan = try? PlanDecoder.decode(extracted) {
                return draft(plan: plan, issues: [], rawText: text, path: .strictJSON)
            }
            if let lenient = try? PlanDecoder.decodeLenient(extracted) {
                return draft(plan: lenient.plan, issues: lenient.issues, rawText: text, path: .lenientJSON)
            }
            if let generic = PlanDraftParser.draft(fromJSON: extracted, memory: memory) {
                return compiled(generic, rawText: text, path: .lenientJSON, exercises: exercises)
            }
            return ParsedPlanDraft(
                plan: nil,
                issues: [ParseIssue(
                    path: "root",
                    severity: .error,
                    message: "这段内容像 JSON，但结构不符合计划契约：需要 schemaVersion、meta 与 7 天 days"
                )],
                rawText: text,
                path: .lenientJSON
            )
        }

        if looksLikeTruncatedJSON(trimmed) {
            return ParsedPlanDraft(
                plan: nil,
                issues: [ParseIssue(
                    path: "root",
                    severity: .error,
                    message: "这段内容像是 JSON，但没粘完整——检查一下括号或代码块是否被截断"
                )],
                rawText: text,
                path: .lenientJSON
            )
        }

        let allLines = trimmed.components(separatedBy: .newlines)
        let firstContent = allLines.firstIndex {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        } ?? 0
        var relevantLines = allLines
        if let boundary = allLines.indices.first(where: {
            $0 > firstContent && (DraftLineScanner.weekNumber(in: allLines[$0]) ?? 1) >= 2
        }) {
            relevantLines = Array(allLines[..<boundary])
        }
        let lineCount = relevantLines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        guard lineCount <= 500 else {
            return ParsedPlanDraft(
                plan: nil,
                issues: [ParseIssue(
                    path: "root",
                    severity: .error,
                    message: "内容太多（超过 500 行），先只粘贴一周的计划"
                )],
                rawText: text,
                path: .blank
            )
        }

        return FreeTextPlanParser.parse(text, memory: memory, exercises: exercises)
    }

    private static func looksLikeTruncatedJSON(_ text: String) -> Bool {
        if text.hasPrefix("```") {
            return text.contains("{")
        }
        if text.hasPrefix("{") || text.hasPrefix("[{") {
            return true
        }
        return text.contains("\"days\"") || text.contains("schemaVersion")
    }

    private static func compiled(
        _ draft: PlanDraft,
        rawText: String,
        path: ParsePath,
        exercises: UserExerciseCatalog
    ) -> ParsedPlanDraft {
        let result = PlanDraftCompiler.compile(draft, exercises: exercises)
        return ParsedPlanDraft(
            plan: result.plan,
            issues: PlanValidator.validate(result.plan),
            rawText: rawText,
            path: path,
            assumptions: result.assumptions,
            unmappedNames: result.unmappedNames,
            guessedItems: result.guessedItems
        )
    }

    private static func draft(
        plan: WorkoutPlan,
        issues: [ParseIssue],
        rawText: String,
        path: ParsePath
    ) -> ParsedPlanDraft {
        let normalized = PlanNormalizer.normalize(plan)
        let validation = PlanValidator.validate(normalized.plan)
        return ParsedPlanDraft(
            plan: normalized.plan,
            issues: issues + normalized.issues + validation,
            rawText: rawText,
            path: path
        )
    }
}

public enum PlanEditing {
    public static func updateItem(
        in plan: WorkoutPlan,
        dayIndex: Int,
        itemId: String,
        sets: Int? = nil,
        value: Int? = nil,
        restSec: Int? = nil,
        catalogId: String? = nil
    ) -> WorkoutPlan {
        var updated = plan
        guard let dayOffset = updated.days.firstIndex(where: { $0.dayIndex == dayIndex }) else {
            return plan
        }

        var changed = false
        for blockOffset in updated.days[dayOffset].blocks.indices {
            guard let itemOffset = updated.days[dayOffset].blocks[blockOffset].items
                .firstIndex(where: { $0.itemId == itemId }) else { continue }

            if let sets {
                updated.days[dayOffset].blocks[blockOffset].items[itemOffset].sets = max(1, sets)
            }
            if let value {
                updated.days[dayOffset].blocks[blockOffset].items[itemOffset].target.value = max(1, value)
            }
            if let restSec {
                updated.days[dayOffset].blocks[blockOffset].items[itemOffset].restSec = max(0, restSec)
            }
            if let catalogId, let entry = ExerciseLibrary.entry(for: catalogId) {
                updated.days[dayOffset].blocks[blockOffset].items[itemOffset].catalogId = catalogId
                updated.days[dayOffset].blocks[blockOffset].items[itemOffset].name = entry.name
                updated.days[dayOffset].blocks[blockOffset].items[itemOffset].load = Load(
                    type: entry.equipment == .dumbbell ? .dumbbell : .bodyweight,
                    value: 0
                )
                if entry.isStatic, updated.days[dayOffset].blocks[blockOffset].items[itemOffset].target.type == .reps {
                    updated.days[dayOffset].blocks[blockOffset].items[itemOffset].target.type = .durationSec
                }
            }
            changed = true
            break
        }

        guard changed else { return plan }
        updated.days[dayOffset].estimatedMinutes = estimatedMinutes(for: updated.days[dayOffset])
        return updated
    }

    public static func estimatedMinutes(for day: PlanDay) -> Int {
        guard !day.isRestDay else { return 0 }
        var seconds = 0
        for block in day.blocks {
            let rounds = max(1, block.rounds)
            let perRound = block.items.reduce(0) { total, item in
                let work = item.target.estimatedWorkSeconds
                return total + item.sets * (work + item.restSec)
            }
            seconds += perRound * rounds
            seconds += block.restBetweenItemsSec * max(0, block.items.count - 1) * rounds
            seconds += block.restBetweenRoundsSec * max(0, rounds - 1)
        }
        return max(1, seconds / 60)
    }
}
