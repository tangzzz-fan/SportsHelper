import Foundation

/// 每 4 周的第 4 周减载：目标值降到 0.6 倍，次数向下取整、最少 1；重量与组数不动。
/// 只影响当周显示与当次训练，不写回计划、不改 `revision`。
public enum DeloadWeek {
    public static let cycleWeeks = 4
    public static let factor = 0.6

    /// 计划第几周。第 1 周是 `startedAt` 所在的那一周，按 7 天一刀切，不按自然周。
    /// 跨年不影响：算的是天数差，不是「第几周」。
    public static func weekIndex(
        on date: Date,
        startedAt: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Int {
        let start = calendar.startOfDay(for: startedAt)
        let today = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        guard days >= 0 else { return 1 }
        return days / 7 + 1
    }

    public static func isDeload(weekIndex: Int) -> Bool {
        guard weekIndex >= 1 else { return false }
        return (weekIndex - 1) % cycleWeeks == cycleWeeks - 1
    }

    public static func isDeloadWeek(
        on date: Date,
        startedAt: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Bool {
        isDeload(weekIndex: weekIndex(on: date, startedAt: startedAt, calendar: calendar))
    }

    /// `enabled` 为 false 时原样返回。没有 `createdAt` 的计划永远不算第 4 周——
    /// 导入的外来计划可能没有起始日，不能凭今天猜。
    public static func applied(
        to plan: WorkoutPlan,
        on date: Date,
        enabled: Bool = true,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> WorkoutPlan {
        guard enabled, let startedAt = plan.createdAt else { return plan }
        guard isDeloadWeek(on: date, startedAt: startedAt, calendar: calendar) else { return plan }

        var next = plan
        next.days = plan.days.map { day in
            var copy = day
            copy.blocks = day.blocks.map { block in
                var updated = block
                updated.items = block.items.map { item in
                    var scaled = item
                    scaled.target = SetTarget(
                        type: item.target.type,
                        value: eased(item.target.value),
                        perSide: item.target.perSide
                    )
                    return scaled
                }
                return updated
            }
            return copy
        }
        return next
    }

    static func eased(_ value: Int) -> Int {
        max(1, Int((Double(value) * factor).rounded(.down)))
    }
}

public extension DeloadWeek {
    /// 计划页与今日页上的一句话。nil 表示这周不减载，不占位。
    static func note(enabled: Bool, weekIndex: Int) -> String? {
        guard enabled, isDeload(weekIndex: weekIndex) else { return nil }
        return "第 \(weekIndex) 周 · 减载周：目标降到六成，重量和组数不动"
    }
}
