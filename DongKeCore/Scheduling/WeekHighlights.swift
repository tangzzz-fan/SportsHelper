import Foundation

public struct WeekHighlights: Equatable, Sendable {
    public var actions: [String]

    public var recordsBroken: Int { actions.count }

    public init(actions: [String] = []) {
        self.actions = actions
    }

    public var headline: String? {
        guard recordsBroken > 0 else { return nil }
        return "这周 \(recordsBroken) 个动作破了纪录"
    }

    public var names: String? {
        guard actions.isEmpty == false else { return nil }
        return actions.prefix(2).joined(separator: "、")
    }
}

public enum WeekHighlightsBuilder {
    public static func build(
        logs: [SetLog],
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> WeekHighlights {
        let start = HistoryStats.weekStart(for: now, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let before = PersonalRecords.build(logs: logs, before: start)

        var seen: Set<RecordKey> = []
        var names: [String] = []

        for log in SessionLedger.distinct(logs) {
            guard log.status == .done,
                  let catalogId = log.catalogId,
                  log.completedAt >= start,
                  log.completedAt < end
            else { continue }

            let key = RecordKey(
                catalogId: catalogId,
                unit: log.targetType ?? PersonalRecords.unit(for: catalogId)
            )
            guard seen.contains(key) == false,
                  let best = before[key]?.best,
                  RecordGate.isRecord(best: best, actual: log.actualValue)
            else { continue }

            seen.insert(key)
            names.append(ExerciseLibrary.entry(for: catalogId)?.name ?? catalogId)
        }

        return WeekHighlights(actions: names.sorted())
    }
}
