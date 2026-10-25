import Foundation

public struct DoseReport: Equatable, Sendable {
    public struct MuscleDose: Equatable, Sendable, Identifiable {
        public var muscle: Muscle
        public var sets: Int
        public var previous: Int

        public var id: String { muscle.rawValue }
        public var delta: Int { sets - previous }

        public init(muscle: Muscle, sets: Int, previous: Int) {
            self.muscle = muscle
            self.sets = sets
            self.previous = previous
        }
    }

    public struct SkipSlice: Equatable, Sendable, Identifiable {
        public var reason: SkipReason
        public var count: Int

        public var id: String { reason.rawValue }

        public init(reason: SkipReason, count: Int) {
            self.reason = reason
            self.count = count
        }
    }

    public var muscles: [MuscleDose]
    public var effectiveSets: Int
    public var completedSets: Int
    public var skippedSets: Int
    public var extraSets: Int
    public var skips: [SkipSlice]
    public var weeklySets: [Int]

    public init(
        muscles: [MuscleDose] = [],
        effectiveSets: Int = 0,
        completedSets: Int = 0,
        skippedSets: Int = 0,
        extraSets: Int = 0,
        skips: [SkipSlice] = [],
        weeklySets: [Int] = []
    ) {
        self.muscles = muscles
        self.effectiveSets = effectiveSets
        self.completedSets = completedSets
        self.skippedSets = skippedSets
        self.extraSets = extraSets
        self.skips = skips
        self.weeklySets = weeklySets
    }

    public var isEmpty: Bool { completedSets == 0 && skippedSets == 0 }

    public var unassignedSets: Int {
        max(0, effectiveSets - muscles.reduce(0) { $0 + $1.sets })
    }
}

public enum DoseReportBuilder {
    public static let defaultWeeks = 4

    public static func build(
        logs: [SetLog],
        now: Date = Date(),
        weeks: Int = defaultWeeks,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> DoseReport {
        let start = HistoryStats.weekStart(for: now, calendar: calendar)
        let currentEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let previousStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start

        let unique = SessionLedger.distinct(logs)
        let thisWeek = unique.filter { $0.completedAt >= start && $0.completedAt < currentEnd }
        let lastWeek = unique.filter { $0.completedAt >= previousStart && $0.completedAt < start }

        let effective = thisWeek.filter(SessionLedger.isEffective)

        var sets: [Muscle: Int] = [:]
        var previous: [Muscle: Int] = [:]
        for log in effective {
            for muscle in muscles(for: log) {
                sets[muscle, default: 0] += 1
            }
        }
        for log in lastWeek where SessionLedger.isEffective(log) {
            for muscle in muscles(for: log) {
                previous[muscle, default: 0] += 1
            }
        }

        var muscles: [DoseReport.MuscleDose] = []
        for muscle in Muscle.allCases {
            let current = sets[muscle] ?? 0
            let before = previous[muscle] ?? 0
            if current > 0 || before > 0 {
                muscles.append(DoseReport.MuscleDose(muscle: muscle, sets: current, previous: before))
            }
        }
        let order = Dictionary(uniqueKeysWithValues: Muscle.allCases.enumerated().map { ($0.element, $0.offset) })
        muscles.sort {
            $0.sets == $1.sets ? (order[$0.muscle] ?? 0) < (order[$1.muscle] ?? 0) : $0.sets > $1.sets
        }

        let skips = SkipReason.allCases.compactMap { reason -> DoseReport.SkipSlice? in
            let count = thisWeek.filter { $0.origin == .prescribed && $0.skipReason == reason }.count
            return count > 0 ? DoseReport.SkipSlice(reason: reason, count: count) : nil
        }
        .sorted { $0.count == $1.count ? $0.reason.rawValue < $1.reason.rawValue : $0.count > $1.count }

        var weeklySets: [Int] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let bucketStart = calendar.date(byAdding: .day, value: -7 * offset, to: start),
                  let bucketEnd = calendar.date(byAdding: .day, value: 7, to: bucketStart) else { continue }
            weeklySets.append(unique.filter {
                $0.completedAt >= bucketStart && $0.completedAt < bucketEnd && SessionLedger.isEffective($0)
            }.count)
        }

        return DoseReport(
            muscles: muscles,
            effectiveSets: effective.count,
            completedSets: thisWeek.filter { $0.origin == .prescribed && $0.status != .skipped }.count,
            skippedSets: thisWeek.filter { $0.origin == .prescribed && $0.status == .skipped }.count,
            extraSets: thisWeek.filter { $0.origin == .extra && $0.status != .skipped }.count,
            skips: skips,
            weeklySets: weeklySets
        )
    }

    static func muscles(for log: SetLog) -> Set<Muscle> {
        guard let catalogId = log.catalogId else { return [] }
        return PrimaryMuscleMap.muscles(for: catalogId)
    }
}
