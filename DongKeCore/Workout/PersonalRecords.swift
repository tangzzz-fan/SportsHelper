import Foundation

public struct RecordKey: Hashable, Sendable {
    public var catalogId: String
    public var unit: SetTargetType

    public init(catalogId: String, unit: SetTargetType) {
        self.catalogId = catalogId
        self.unit = unit
    }
}

public struct PersonalRecord: Equatable, Sendable {
    public var last: Int?
    public var best: Int?
    public var timesDone: Int
    public var lastDate: Date?
    public var bestDate: Date?

    public init(last: Int? = nil, best: Int? = nil, timesDone: Int = 0, lastDate: Date? = nil, bestDate: Date? = nil) {
        self.last = last
        self.best = best
        self.timesDone = timesDone
        self.lastDate = lastDate
        self.bestDate = bestDate
    }
}

public extension PersonalRecord {
    func lineText(unit: SetTargetType) -> String? {
        guard let last else { return nil }
        let lastText = "上次 \(Self.valueText(last, unit: unit))"
        guard let best else { return lastText }
        return "\(lastText) · 最好 \(Self.valueText(best, unit: unit))"
    }

    static func valueText(_ value: Int, unit: SetTargetType) -> String {
        switch unit {
        case .durationSec: "\(value) 秒"
        case .distanceM: "\(value) 米"
        case .reps: "\(value)"
        }
    }
}

public enum PersonalRecords {
    public static func build(
        logs: [SetLog],
        before: Date = .distantFuture
    ) -> [RecordKey: PersonalRecord] {
        var sessions: [RecordKey: [UUID: SessionTally]] = [:]

        for log in SessionLedger.distinct(logs) {
            guard let catalogId = log.catalogId,
                  log.completedAt < before,
                  log.status != .skipped
            else { continue }

            let key = RecordKey(
                catalogId: catalogId,
                unit: log.targetType ?? unit(for: catalogId)
            )
            var tally = sessions[key, default: [:]][log.sessionId] ?? SessionTally(at: log.completedAt)
            tally.at = max(tally.at, log.completedAt)
            tally.anyValue = max(tally.anyValue ?? 0, log.actualValue)
            if log.status == .done {
                tally.doneValue = max(tally.doneValue ?? 0, log.actualValue)
            }
            sessions[key, default: [:]][log.sessionId] = tally
        }

        var result: [RecordKey: PersonalRecord] = [:]
        for (key, tallyBySession) in sessions {
            let ordered = tallyBySession.values.sorted { $0.at > $1.at }
            guard let latest = ordered.first else { continue }

            let best = tallyBySession.values
                .compactMap { tally in tally.doneValue.map { (value: $0, at: tally.at) } }
                .max { $0.value < $1.value }

            result[key] = PersonalRecord(
                last: latest.doneValue ?? latest.anyValue,
                best: best?.value,
                timesDone: tallyBySession.values.filter { $0.doneValue != nil }.count,
                lastDate: latest.at,
                bestDate: best?.at
            )
        }
        return result
    }

    public static func unit(for catalogId: String) -> SetTargetType {
        guard let entry = ExerciseLibrary.entry(for: catalogId), entry.isStatic else {
            return .reps
        }
        return .durationSec
    }
}

private struct SessionTally {
    var at: Date
    var doneValue: Int?
    var anyValue: Int?

    init(at: Date) {
        self.at = at
    }
}
