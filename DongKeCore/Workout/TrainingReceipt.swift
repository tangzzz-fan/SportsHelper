import Foundation

/// 训练回执：把最近几周的执行情况汇成一段可复制的文本，交给计划的来源（ChatGPT / 教练）修订。
///
/// 它只陈述事实，不提建议——App 对外来计划依然不主动给建议（ADR-0003）。
/// 出口只有复制与系统分享，不联网。
public struct TrainingReceipt: Equatable, Sendable {
    public struct ActionLine: Equatable, Sendable {
        public var name: String
        public var planText: String
        public var actualText: String
        public var downgraded: Int
        public var skipped: Int
        public var skipReasons: [String]
        public var best: Int

        public init(
            name: String,
            planText: String,
            actualText: String,
            downgraded: Int,
            skipped: Int,
            skipReasons: [String],
            best: Int
        ) {
            self.name = name
            self.planText = planText
            self.actualText = actualText
            self.downgraded = downgraded
            self.skipped = skipped
            self.skipReasons = skipReasons
            self.best = best
        }
    }

    public var weeks: Int
    public var effectiveSets: Int
    public var actions: [ActionLine]
    public var painActions: [String]

    public init(
        weeks: Int,
        effectiveSets: Int,
        actions: [ActionLine],
        painActions: [String]
    ) {
        self.weeks = weeks
        self.effectiveSets = effectiveSets
        self.actions = actions
        self.painActions = painActions
    }

    /// 正文，不含 schema。空记录时只留一句「没有记录」，不硬凑。
    public var body: String {
        var lines: [String] = []
        lines.append("动刻训练回执 · 最近 \(weeks) 周")
        lines.append("")

        guard actions.isEmpty == false else {
            lines.append("这段时间没有训练记录。")
            return lines.joined(separator: "\n")
        }

        lines.append("有效组 \(effectiveSets)")
        lines.append("")
        lines.append("动作 | 计划 | 最近一节实际 | 降阶 | 跳过 | 最好")
        for action in actions {
            var cells = [action.name, action.planText, action.actualText]
            cells.append(action.downgraded > 0 ? "\(action.downgraded)" : "0")
            if action.skipped > 0 {
                let reasons = action.skipReasons.isEmpty ? "" : "（\(action.skipReasons.joined(separator: "、"))）"
                cells.append("\(action.skipped)\(reasons)")
            } else {
                cells.append("0")
            }
            cells.append(action.best > 0 ? "\(action.best)" : "—")
            lines.append(cells.joined(separator: " | "))
        }

        if painActions.isEmpty == false {
            lines.append("")
            lines.append("疼痛：\(painActions.joined(separator: "、"))")
        }
        return lines.joined(separator: "\n")
    }

    /// 复制出去的全部内容：正文 + 修订提示 + 计划 schema。
    public var text: String {
        """
        \(body)

        请据此修订计划，并按下面的 schema 输出：
        \(PlanSchemaJSON.text)
        """
    }

    /// 塞进 AI 提示词的摘要：只留正文，压到 1200 字以内，行不会被拦腰截断。
    /// 不带 schema——schema 在 system prompt 里，重复一遍只会挤掉记录本身。
    public var summary: String {
        let limit = TrainingReceipt.summaryLimit
        guard body.count > limit else { return body }

        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var kept: [String] = []
        var used = 0
        for line in lines {
            let cost = line.count + 1
            // 留 30 字给末尾那句「另有 N 行未列出」。
            if used + cost > limit - 30 { break }
            kept.append(line)
            used += cost
        }
        let dropped = lines.count - kept.count
        return kept.joined(separator: "\n") + "\n…（另有 \(dropped) 行未列出）"
    }

    public static let summaryLimit = 1200
}

public enum TrainingReceiptBuilder {
    private typealias ActionLine = TrainingReceipt.ActionLine

    public static func build(
        logs: [SetLog],
        plan: WorkoutPlan,
        weeks: Int = 4,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> TrainingReceipt {
        let start = calendar.date(byAdding: .day, value: -7 * weeks, to: now) ?? now
        let recent = logs.filter { $0.completedAt >= start && $0.catalogId != nil }
        let records = PersonalRecords.build(logs: logs)
        let items = Dictionary(
            plan.days.flatMap { $0.blocks.flatMap(\.items) }.map { ($0.catalogId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var grouped: [String: [SetLog]] = [:]
        for log in recent {
            guard let id = log.catalogId else { continue }
            grouped[id, default: []].append(log)
        }

        var actions: [ActionLine] = []
        var painActions: [String] = []

        for (catalogId, group) in grouped {
            let name = ExerciseLibrary.entry(for: catalogId)?.name
                ?? items[catalogId]?.name
                ?? catalogId
            let ordered = group.sorted { $0.completedAt > $1.completedAt }
            let latestSession = ordered.first?.sessionId
            let latest = group
                .filter { $0.sessionId == latestSession && $0.status != .skipped }
                .sorted { $0.setIndex < $1.setIndex }

            let planText = items[catalogId].map { describe($0) } ?? "未在当前计划里"
            let actualText = latest.isEmpty
                ? "—"
                : latest.map { "\($0.actualValue)" }.joined(separator: "/")

            let unit = ordered.first?.targetType ?? PersonalRecords.unit(for: catalogId)
            let loadKey = ordered.first?.actualLoad?.recordKey ?? RecordKey.unspecifiedLoad
            let best = records[RecordKey(catalogId: catalogId, unit: unit, loadKey: loadKey)]?.best ?? 0

            let downgraded = group.filter { $0.status == .downgraded }.count
            let skipped = group.filter { $0.status == .skipped }
            let reasons = Array(Set(skipped.compactMap { $0.skipReason?.chineseName })).sorted()
            if skipped.contains(where: { $0.skipReason == .pain }) {
                painActions.append(name)
            }

            actions.append(ActionLine(
                name: name,
                planText: planText,
                actualText: actualText,
                downgraded: downgraded,
                skipped: skipped.count,
                skipReasons: reasons,
                best: best
            ))
        }

        let effective = recent.filter { SessionLedger.isEffective($0) }.count
        return TrainingReceipt(
            weeks: weeks,
            effectiveSets: effective,
            actions: actions.sorted { $0.name < $1.name },
            painActions: painActions.sorted()
        )
    }

    private static func describe(_ item: ExercisePrescription) -> String {
        let target = item.target
        let perSide = target.perSide ? "/侧" : ""
        let load = item.load.shortText.map { " · \($0)" } ?? ""
        return "\(item.sets)×\(target.doseText)\(perSide)\(load)"
    }
}
