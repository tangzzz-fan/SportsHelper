import Foundation

public enum Prediction {
    public static let repCeiling = 15
    public static let holdCeilingSeconds = 60
    public static let holdStepSeconds = 5

    public static func next(record: PersonalRecord, unit: SetTargetType, lastRPE: Int?) -> Int? {
        guard let base = record.last else { return nil }
        let hasRoom = (lastRPE ?? Int.max) <= 2

        switch unit {
        case .distanceM:
            return nil
        case .reps:
            return min(repCeiling, base + (hasRoom ? 1 : 0))
        case .durationSec:
            return min(holdCeilingSeconds, base + (hasRoom ? holdStepSeconds : 0))
        }
    }
}

public struct PredictionCalibration: Equatable, Sendable {
    public struct Week: Equatable, Sendable, Identifiable {
        public var start: Date
        public var meanAbsoluteError: Double
        public var sampleSize: Int

        public var id: Date { start }

        public init(start: Date, meanAbsoluteError: Double, sampleSize: Int) {
            self.start = start
            self.meanAbsoluteError = meanAbsoluteError
            self.sampleSize = sampleSize
        }
    }

    public var unit: SetTargetType
    public var weeks: [Week]

    public init(unit: SetTargetType = .reps, weeks: [Week] = []) {
        self.unit = unit
        self.weeks = weeks
    }

    public var sampleSize: Int { weeks.reduce(0) { $0 + $1.sampleSize } }

    public var isPublishable: Bool {
        weeks.count >= 2 && sampleSize >= 12
    }

    public var latest: Double? { weeks.last?.meanAbsoluteError }

    public var headline: String? {
        guard isPublishable, let last = weeks.last, let first = weeks.first else { return nil }
        let unitText = unit == .durationSec ? "秒" : "个"
        let now = String(format: "%.1f", last.meanAbsoluteError)
        let before = String(format: "%.1f", first.meanAbsoluteError)
        let gap = max(1, Int((last.start.timeIntervalSince(first.start) / 604_800).rounded()))
        if last.meanAbsoluteError < first.meanAbsoluteError {
            return "比 \(gap) 周前准了：最近一周平均差 \(now) \(unitText)，之前是 \(before) \(unitText)"
        }
        return "最近一周平均差 \(now) \(unitText)，\(gap) 周前是 \(before) \(unitText)"
    }
}

public enum PredictionCalibrationBuilder {
    public static let defaultWeeks = 4

    public static func build(
        logs: [SetLog],
        now: Date = Date(),
        weeks: Int = defaultWeeks,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> PredictionCalibration {
        let currentStart = HistoryStats.weekStart(for: now, calendar: calendar)
        let starts: [Date] = (0..<weeks).reversed().compactMap {
            calendar.date(byAdding: .day, value: -7 * $0, to: currentStart)
        }

        var samples: [(date: Date, unit: SetTargetType, error: Int)] = []
        for log in SessionLedger.distinct(logs) {
            guard log.status == .done,
                  let predicted = log.predictedValue,
                  let catalogId = log.catalogId
            else { continue }
            let unit = log.targetType ?? PersonalRecords.unit(for: catalogId)
            samples.append((log.completedAt, unit, abs(predicted - log.actualValue)))
        }
        guard samples.isEmpty == false else {
            return PredictionCalibration(unit: .reps, weeks: [])
        }

        let dominant = Dictionary(grouping: samples, by: \.unit)
            .max { $0.value.count < $1.value.count }?
            .key ?? .reps
        let chosen = samples.filter { $0.unit == dominant }

        var result: [PredictionCalibration.Week] = []
        for start in starts {
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            let bucket = chosen.filter { $0.date >= start && $0.date < end }
            guard bucket.isEmpty == false else { continue }
            let mean = Double(bucket.reduce(0) { $0 + $1.error }) / Double(bucket.count)
            result.append(PredictionCalibration.Week(start: start, meanAbsoluteError: mean, sampleSize: bucket.count))
        }
        return PredictionCalibration(unit: dominant, weeks: result)
    }
}
