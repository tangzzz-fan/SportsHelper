import Foundation

public struct SessionRecap: Equatable, Sendable {
    public var plannedSets: Int
    public var doneSets: Int
    public var downgradedSets: Int
    public var skippedSets: Int
    public var duration: TimeInterval

    public init(
        plannedSets: Int,
        doneSets: Int,
        downgradedSets: Int,
        skippedSets: Int,
        duration: TimeInterval
    ) {
        self.plannedSets = max(0, plannedSets)
        self.doneSets = max(0, doneSets)
        self.downgradedSets = max(0, downgradedSets)
        self.skippedSets = max(0, skippedSets)
        self.duration = max(0, duration)
    }

    public init(logs: [SetLog], plannedSets: Int, startedAt: Date, finishedAt: Date) {
        self.init(
            plannedSets: plannedSets,
            doneSets: logs.filter { $0.status == .done }.count,
            downgradedSets: logs.filter { $0.status == .downgraded }.count,
            skippedSets: logs.filter { $0.status == .skipped }.count,
            duration: finishedAt.timeIntervalSince(startedAt)
        )
    }

    public var loggedSets: Int {
        doneSets + downgradedSets + skippedSets
    }

    public var completedSets: Int {
        doneSets + downgradedSets
    }

    public var completionRate: Double {
        rate(completedSets)
    }

    public var downgradeRate: Double {
        rate(downgradedSets)
    }

    public var skipRate: Double {
        rate(skippedSets)
    }

    public var isClean: Bool {
        plannedSets > 0 && downgradedSets == 0 && skippedSets == 0 && loggedSets == plannedSets
    }

    public func percentText(_ rate: Double) -> String {
        "\(Int((min(1, max(0, rate)) * 100).rounded()))%"
    }

    public var durationText: String {
        let total = Int(duration.rounded())
        if total >= 3600 {
            return "\(total / 3600) 小时 \(total % 3600 / 60) 分"
        }
        if total >= 60 {
            let seconds = total % 60
            return seconds == 0 ? "\(total / 60) 分钟" : "\(total / 60) 分 \(seconds) 秒"
        }
        return "\(total) 秒"
    }

    private func rate(_ value: Int) -> Double {
        HistoryStats.rate(value, of: plannedSets) ?? 0
    }
}
