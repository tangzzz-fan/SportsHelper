import Foundation

/// 训练日当天把这一节压成 10 / 15 / 20 分钟。
///
/// 规则：每个主导肌群保留第一个动作，其余同肌群动作丢掉；组数按时间比例削减，
/// 最少 1 组；次数与重量不动。不改计划、不改 `revision`——它只影响这一次会话。
public enum SessionCompressor {
    public static func compress(_ day: PlanDay, toMinutes minutes: Int) -> PlanDay {
        guard minutes > 0, day.estimatedMinutes > 0 else { return day }
        let allItems = day.blocks.flatMap(\.items)
        guard allItems.isEmpty == false else { return day }

        let ratio = min(1, Double(minutes) / Double(day.estimatedMinutes))

        var seenGroups: Set<ExerciseGroup> = []
        var keptIds: Set<String> = []
        for item in allItems {
            guard let group = ExerciseLibrary.entry(for: item.catalogId)?.group else {
                keptIds.insert(item.itemId)
                continue
            }
            if seenGroups.insert(group).inserted {
                keptIds.insert(item.itemId)
            }
        }

        let blocks = day.blocks.compactMap { block -> ExerciseBlock? in
            let items = block.items
                .filter { keptIds.contains($0.itemId) }
                .map { item -> ExercisePrescription in
                    var copy = item
                    copy.sets = max(1, Int((Double(item.sets) * ratio).rounded()))
                    return copy
                }
            guard items.isEmpty == false else { return nil }
            var copy = block
            copy.items = items
            return copy
        }

        var result = day
        result.blocks = blocks
        result.estimatedMinutes = minutes
        return result
    }
}
