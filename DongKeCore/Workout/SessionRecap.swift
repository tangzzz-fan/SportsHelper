import Foundation

public struct SessionRecap: Equatable, Sendable {
    public let ledger: SessionLedger
    public var duration: TimeInterval

    public init(ledger: SessionLedger, duration: TimeInterval) {
        self.ledger = ledger
        self.duration = max(0, duration)
    }

    public init(logs: [SetLog], plannedSets: Int, startedAt: Date, finishedAt: Date) {
        self.init(
            ledger: SessionLedger(prescribedSets: plannedSets, logs: logs),
            duration: finishedAt.timeIntervalSince(startedAt)
        )
    }

    public var plannedSets: Int { ledger.prescribedSets }
    public var doneSets: Int { ledger.doneSets }
    public var downgradedSets: Int { ledger.downgradedSets }
    public var skippedSets: Int { ledger.skippedSets }
    public var extraSets: Int { ledger.extraSets }
    public var completedSets: Int { ledger.completedSets }

    public var completionRate: Double { ledger.completionRate ?? 0 }
    public var downgradeRate: Double { ledger.downgradeRate ?? 0 }
    public var skipRate: Double { ledger.skipRate ?? 0 }
    public var isClean: Bool { ledger.isClean }

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
}
