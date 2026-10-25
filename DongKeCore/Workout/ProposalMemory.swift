import Foundation

public struct ProposalMemory: Equatable, Sendable, Codable {
    public struct Entry: Equatable, Sendable, Codable {
        public var fingerprint: String
        public var at: Date

        public init(fingerprint: String, at: Date) {
            self.fingerprint = fingerprint
            self.at = at
        }
    }

    public struct AcceptedChange: Equatable, Sendable, Codable {
        public var itemId: String
        public var at: Date

        public init(itemId: String, at: Date) {
            self.itemId = itemId
            self.at = at
        }
    }

    public static let silenceThreshold = 3
    public static let historyLimit = 30

    public static let defaultAmplitude = 1.025
    public static let carefulAmplitude = 1.0125
    public static let boldAmplitude = 1.05

    public var rejected: [Entry]
    public var acceptedChanges: [AcceptedChange]
    public var consecutiveRejections: Int
    public var doseStreak: Int
    public var lastDeloadAt: Date?
    public var recentSetbacks: [Int]
    public var pendingSetbackSince: Date?
    public var pendingItemIds: [String]

    public static let empty = ProposalMemory()

    public init(
        rejected: [Entry] = [],
        acceptedChanges: [AcceptedChange] = [],
        consecutiveRejections: Int = 0,
        doseStreak: Int = 0,
        lastDeloadAt: Date? = nil,
        recentSetbacks: [Int] = [],
        pendingSetbackSince: Date? = nil,
        pendingItemIds: [String] = []
    ) {
        self.rejected = rejected
        self.acceptedChanges = acceptedChanges
        self.consecutiveRejections = consecutiveRejections
        self.doseStreak = doseStreak
        self.lastDeloadAt = lastDeloadAt
        self.recentSetbacks = recentSetbacks
        self.pendingSetbackSince = pendingSetbackSince
        self.pendingItemIds = pendingItemIds
    }

    public var loadAmplitude: Double {
        let recent = Array(recentSetbacks.suffix(2))
        guard recent.count == 2 else { return Self.defaultAmplitude }
        if recent.allSatisfy({ $0 <= 1 }) { return Self.carefulAmplitude }
        if recent.allSatisfy({ $0 >= 3 }) { return Self.boldAmplitude }
        return Self.defaultAmplitude
    }

    public func recordingSetback(_ index: Int) -> ProposalMemory {
        var next = self
        next.recentSetbacks.append(index)
        if next.recentSetbacks.count > 2 {
            next.recentSetbacks.removeFirst(next.recentSetbacks.count - 2)
        }
        next.pendingSetbackSince = nil
        next.pendingItemIds = []
        return next
    }

    public var isSilenced: Bool {
        consecutiveRejections >= Self.silenceThreshold
    }

    public func hasRejected(_ proposal: PlanProposal) -> Bool {
        rejected.contains { $0.fingerprint == proposal.fingerprint }
    }

    public func accepting(_ proposal: PlanProposal, now: Date) -> ProposalMemory {
        var next = self
        next.consecutiveRejections = 0
        if proposal.kind == .dose {
            if proposal.isReduction {
                next.doseStreak = 0
                next.lastDeloadAt = now
            } else {
                next.doseStreak += 1
            }
        }
        next.acceptedChanges += proposal.changes.map { AcceptedChange(itemId: $0.itemId, at: now) }
        if proposal.kind == .dose, proposal.isReduction == false {
            next.pendingSetbackSince = now
            next.pendingItemIds = proposal.changes.map(\.itemId)
        }
        if next.acceptedChanges.count > Self.historyLimit {
            next.acceptedChanges.removeFirst(next.acceptedChanges.count - Self.historyLimit)
        }
        return next
    }

    public func settling(logs: [SetLog], now: Date = Date()) -> ProposalMemory {
        guard let since = pendingSetbackSince else { return self }
        let sessions = Dictionary(grouping: logs.filter {
            $0.origin == .prescribed
                && $0.completedAt > since
                && pendingItemIds.contains($0.prescriptionId)
        }, by: \.sessionId)
        let ordered = sessions.values.sorted {
            ($0.map(\.completedAt).min() ?? now) < ($1.map(\.completedAt).min() ?? now)
        }
        for (index, group) in ordered.enumerated() where group.contains(where: { $0.status != .done }) {
            return recordingSetback(index + 1)
        }
        if ordered.count >= 3 { return recordingSetback(3) }
        return self
    }

    public func rejecting(_ proposal: PlanProposal, now: Date) -> ProposalMemory {
        var next = self
        next.consecutiveRejections += 1
        next.rejected.append(Entry(fingerprint: proposal.fingerprint, at: now))
        if next.rejected.count > Self.historyLimit {
            next.rejected.removeFirst(next.rejected.count - Self.historyLimit)
        }
        return next
    }
}
