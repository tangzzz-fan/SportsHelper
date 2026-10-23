import Foundation

public enum PlanValidator {
    private static let setsRange = 1...20
    private static let restRange = 0...600
    private static let roundsRange = 1...20
    private static let sessionMinutesRange = 5...120

    public static func validate(_ plan: WorkoutPlan) -> [ParseIssue] {
        var issues: [ParseIssue] = []

        if plan.schemaVersion != 1 {
            issues.append(issue("schemaVersion", "不支持的计划结构版本"))
        }
        if plan.days.count != 7 {
            issues.append(issue("days", "一周必须有 7 天，当前 \(plan.days.count) 天"))
        }
        if plan.meta.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("meta.title", "计划名称不能为空"))
        }
        if !sessionMinutesRange.contains(plan.meta.sessionMinutes) {
            issues.append(issue("meta.sessionMinutes", "单次时长须在 5 到 120 分钟之间"))
        }

        let trainingDays = plan.days.filter { !$0.isRestDay }.count
        if !(1...7).contains(plan.meta.daysPerWeek) {
            issues.append(issue("meta.daysPerWeek", "每周训练天数须在 1 到 7 之间"))
        } else if plan.meta.daysPerWeek != trainingDays {
            issues.append(issue("meta.daysPerWeek", "每周训练天数与训练日数量不一致"))
        }

        for (dayOffset, day) in plan.days.enumerated() {
            let dayPath = "days[\(dayOffset)]"

            if day.dayIndex != dayOffset + 1 {
                issues.append(issue("\(dayPath).dayIndex", "周内序号须从 1 到 7 且与位置一致"))
            }
            if day.weekday.rawValue != day.dayIndex {
                issues.append(issue("\(dayPath).weekday", "星期与周内序号不一致"))
            }

            if day.isRestDay {
                if !day.blocks.isEmpty {
                    issues.append(issue("\(dayPath).blocks", "休息日不应包含训练区块"))
                }
                continue
            }

            if day.blocks.isEmpty {
                issues.append(issue("\(dayPath).blocks", "训练日没有任何区块"))
            }

            let dayItemCount = day.blocks.reduce(0) { $0 + $1.items.count }
            if dayItemCount > 20 {
                issues.append(issue("\(dayPath).blocks", "这一天有 \(dayItemCount) 个动作，动作过多，先只保留一周的计划"))
            }

            for (blockOffset, block) in day.blocks.enumerated() {
                let blockPath = "\(dayPath).blocks[\(blockOffset)]"
                if !roundsRange.contains(block.rounds) {
                    issues.append(issue("\(blockPath).rounds", "轮数须在 1 到 20 之间"))
                }
                if !restRange.contains(block.restBetweenItemsSec) {
                    issues.append(issue("\(blockPath).restBetweenItemsSec", "动作间休息须在 0 到 600 秒之间"))
                }
                if !restRange.contains(block.restBetweenRoundsSec) {
                    issues.append(issue("\(blockPath).restBetweenRoundsSec", "轮间休息须在 0 到 600 秒之间"))
                }
                if block.items.isEmpty {
                    issues.append(issue("\(blockPath).items", "区块内没有任何动作"))
                }

                for (itemOffset, item) in block.items.enumerated() {
                    let itemPath = "\(blockPath).items[\(itemOffset)]"
                    if !setsRange.contains(item.sets) {
                        issues.append(issue("\(itemPath).sets", "组数须在 1 到 20 之间"))
                    }
                    if !restRange.contains(item.restSec) {
                        issues.append(issue("\(itemPath).restSec", "组间休息须在 0 到 600 秒之间"))
                    }
                    if item.target.value <= 0 {
                        issues.append(issue("\(itemPath).target.value", "目标次数或时长必须大于 0"))
                    }
                    if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        issues.append(issue("\(itemPath).name", "动作名称不能为空"))
                    }
                    if item.catalogId.isEmpty {
                        issues.append(issue("\(itemPath).catalogId", "动作库标识不能为空"))
                    }
                }
            }
        }

        return issues
    }

    private static func issue(_ path: String, _ message: String) -> ParseIssue {
        ParseIssue(path: path, severity: .error, message: message)
    }
}
