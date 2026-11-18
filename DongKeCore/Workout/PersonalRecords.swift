import Foundation

public struct RecordKey: Hashable, Sendable {
    /// 旧日志没有重量时落在这里。查询只在「用户没改重量」时才回落到它。
    public static let unspecifiedLoad = "unspecified"

    public var catalogId: String
    public var unit: SetTargetType
    public var loadKey: String

    public init(
        catalogId: String,
        unit: SetTargetType,
        loadKey: String = RecordKey.unspecifiedLoad
    ) {
        self.catalogId = catalogId
        self.unit = unit
        self.loadKey = loadKey
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
    func lineText(unit: SetTargetType, loadText: String? = nil) -> String? {
        guard let last else { return nil }
        let prefix = loadText.map { "\($0) · " } ?? ""
        let lastText = "\(prefix)上次 \(Self.valueText(last, unit: unit))"
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

public enum RecordGate {
    public static func isRecord(best: Int?, actual: Int) -> Bool {
        guard let best else { return false }
        return actual > best
    }
}

public enum RecordCelebration {
    public static func text(
        name: String,
        value: Int,
        unit: SetTargetType,
        loadText: String? = nil
    ) -> String? {
        let weight = loadText.map { " \($0) " } ?? ""
        switch unit {
        case .reps: return "\(name)\(weight)最高纪录 \(value) 个"
        case .durationSec: return "\(name)\(weight)最长 \(value) 秒"
        case .distanceM: return nil
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
                unit: log.targetType ?? unit(for: catalogId),
                loadKey: log.actualLoad?.recordKey ?? RecordKey.unspecifiedLoad
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

    /// 查某个重量下的纪录。先精确匹配；只有用户没改重量时，才回落到旧日志的
    /// `unspecified` 桶——换了重量还拿旧数据当「上次」，比没有更糟。
    public static func record(
        for catalogId: String,
        unit: SetTargetType,
        load: Load?,
        isUsingPrescribedLoad: Bool,
        in records: [RecordKey: PersonalRecord]
    ) -> PersonalRecord? {
        if let load,
           let exact = records[RecordKey(catalogId: catalogId, unit: unit, loadKey: load.recordKey)] {
            return exact
        }
        guard isUsingPrescribedLoad else { return nil }
        return records[RecordKey(catalogId: catalogId, unit: unit)]
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
