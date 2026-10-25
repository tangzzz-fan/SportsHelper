import Foundation

struct SetLogKey: Hashable {
    var sessionId: UUID
    var prescriptionId: String
    var setIndex: Int
    var origin: SetOrigin

    init(_ log: SetLog) {
        sessionId = log.sessionId
        prescriptionId = log.prescriptionId
        setIndex = log.setIndex
        origin = log.origin
    }
}

public struct SessionLedger: Equatable, Sendable {
    public let prescribedSets: Int
    private let logs: [SetLog]
    private let tally: Tally

    private struct Tally: Equatable, Sendable {
        var done = 0
        var downgraded = 0
        var skipped = 0
        var extraDone = 0
        var extraDowngraded = 0
    }

    public init(prescribedSets: Int, logs: [SetLog]) {
        self.prescribedSets = max(0, prescribedSets)
        let distinct = Self.distinct(logs)
        self.logs = distinct
        var tally = Tally()
        for log in distinct {
            switch (log.origin, log.status) {
            case (.prescribed, .done): tally.done += 1
            case (.prescribed, .downgraded): tally.downgraded += 1
            case (.prescribed, .skipped): tally.skipped += 1
            case (.extra, .done): tally.extraDone += 1
            case (.extra, .downgraded): tally.extraDowngraded += 1
            case (.extra, .skipped): break
            }
        }
        self.tally = tally
    }

    public var doneSets: Int { tally.done }
    public var downgradedSets: Int { tally.downgraded }
    public var skippedSets: Int { tally.skipped }

    public var completedSets: Int {
        tally.done + tally.downgraded
    }

    public var extraSets: Int {
        tally.extraDone + tally.extraDowngraded
    }

    public var isComplete: Bool {
        prescribedSets > 0 && completedSets >= prescribedSets
    }

    public var isClean: Bool {
        prescribedSets > 0 && tally.done == prescribedSets && tally.downgraded == 0 && tally.skipped == 0
    }

    public var completionRate: Double? {
        HistoryStats.rate(completedSets, of: prescribedSets)
    }

    public var downgradeRate: Double? {
        HistoryStats.rate(tally.downgraded, of: prescribedSets)
    }

    public var skipRate: Double? {
        HistoryStats.rate(tally.skipped, of: prescribedSets)
    }

    public static func isEffective(_ log: SetLog) -> Bool {
        log.status == .done && (log.rpe ?? 5) >= 2
    }

    static func distinct(_ logs: [SetLog]) -> [SetLog] {
        var seen = Set<SetLogKey>()
        return logs.filter { seen.insert(SetLogKey($0)).inserted }
    }
}
