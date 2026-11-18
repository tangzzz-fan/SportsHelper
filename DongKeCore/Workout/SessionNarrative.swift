import Foundation

/// 训练结束后的那一句判断。
///
/// 只在该说话的时候说话：有破纪录说破纪录，降阶多得离谱说一句体力分配，
/// 其余情况返回 `nil`——沉默比「继续加油」有信息。
public enum SessionNarrative {
    public static func headline(
        logs: [SetLog],
        history: [SetLog],
        recap: SessionRecap
    ) -> String? {
        recordLine(logs: logs, history: history)
            ?? downgradeLine(logs: logs, recap: recap)
    }

    private static func recordLine(logs: [SetLog], history: [SetLog]) -> String? {
        let records = PersonalRecords.build(logs: history)
        let done = logs
            .filter { $0.status == .done && $0.catalogId != nil }
            .sorted { $0.actualValue > $1.actualValue }

        for log in done {
            guard let catalogId = log.catalogId else { continue }
            let unit = log.targetType ?? PersonalRecords.unit(for: catalogId)
            let key = RecordKey(
                catalogId: catalogId,
                unit: unit,
                loadKey: log.actualLoad?.recordKey ?? RecordKey.unspecifiedLoad
            )
            guard let best = records[key]?.best, log.actualValue > best else { continue }

            let name = ExerciseLibrary.entry(for: catalogId)?.name ?? catalogId
            let doneText = amount(log.actualValue, unit: unit)
            let delta = amount(log.actualValue - best, unit: unit)
            if let weight = log.actualLoad?.shortText {
                return "\(name) \(weight) 做了 \(doneText)，比上次多 \(delta)"
            }
            return "\(name) 做了 \(doneText)，比上次多 \(delta)"
        }
        return nil
    }

    private static func downgradeLine(logs: [SetLog], recap: SessionRecap) -> String? {
        guard recap.downgradeRate > 0.3 else { return nil }
        let downgraded = logs.filter { $0.status == .downgraded }
        guard let worst = downgraded.min(by: { $0.actualValue < $1.actualValue }),
              let catalogId = worst.catalogId
        else { return nil }

        let name = ExerciseLibrary.entry(for: catalogId)?.name ?? catalogId
        let unit = worst.targetType ?? PersonalRecords.unit(for: catalogId)
        let done = amount(worst.actualValue, unit: unit)

        guard unit == .reps, worst.setIndex > 1 else {
            return "\(name) 有 \(downgraded.count) 组降阶了，下次把目标调低一档"
        }
        return "\(name)第 \(worst.setIndex) 组只做了 \(done)，下次前 \(worst.setIndex - 1) 组各留 1 个余力"
    }

    private static func amount(_ value: Int, unit: SetTargetType) -> String {
        switch unit {
        case .reps: "\(value) 个"
        case .durationSec: "\(value) 秒"
        case .distanceM: "\(value) 米"
        }
    }
}
