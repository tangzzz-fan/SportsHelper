import Foundation

public enum PlanImportService {
    private static let maxBytes = 64 * 1024

    public static func parse(_ text: String) -> ParsedPlanDraft {
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

        if PlanJSONExtractor.extract(from: trimmed) != nil {
            if let plan = try? PlanDecoder.decode(trimmed) {
                return draft(plan: plan, issues: [], rawText: text, path: .strictJSON)
            }
            if let lenient = try? PlanDecoder.decodeLenient(trimmed) {
                return draft(plan: lenient.plan, issues: lenient.issues, rawText: text, path: .lenientJSON)
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

        return FreeTextPlanParser.parse(text)
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
        restSec: Int? = nil
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
                let work = item.target.type == .durationSec ? item.target.value : item.target.value * 3
                return total + item.sets * (work + item.restSec)
            }
            seconds += perRound * rounds
            seconds += block.restBetweenItemsSec * max(0, block.items.count - 1) * rounds
            seconds += block.restBetweenRoundsSec * max(0, rounds - 1)
        }
        return max(1, seconds / 60)
    }
}
