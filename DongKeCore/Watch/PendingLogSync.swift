import Foundation

public protocol PendingLogSending: Sendable {
    func send(_ entry: PendingSetLog) async throws
}

/// 指数退避：5s → 10s → 30s，之后固定 30s。成功后清零。
public struct LogRetryScheduler: Equatable, Sendable {
    public static let backoff: [TimeInterval] = [5, 10, 30]
    public static let alertAfter: TimeInterval = 24 * 60 * 60

    public private(set) var failureCount = 0
    public private(set) var nextAttemptAt: Date?

    public init() {}

    public func canAttempt(now: Date) -> Bool {
        guard let nextAttemptAt else { return true }
        return now >= nextAttemptAt
    }

    @discardableResult
    public mutating func recordFailure(now: Date) -> TimeInterval {
        failureCount += 1
        let index = min(failureCount, Self.backoff.count) - 1
        let delay = Self.backoff[index]
        nextAttemptAt = now.addingTimeInterval(delay)
        return delay
    }

    public mutating func recordSuccess() {
        failureCount = 0
        nextAttemptAt = nil
    }
}

public enum PendingLogFlushOutcome: Equatable, Sendable {
    case empty
    case busy
    case backingOff(until: Date)
    case sent(Int)
    case failed(sent: Int, remaining: Int, retryAfter: TimeInterval)
}

/// Watch 侧待发日志队列。持久化在 App Group，重试状态只在内存——
/// 冷启动后失败计数归零，下一次前台会立刻重试，这是我们要的。
public actor PendingLogQueue {
    private let store: AppGroupsStore
    private var scheduler = LogRetryScheduler()
    private var isSending = false

    public init(store: AppGroupsStore) {
        self.store = store
    }

    @discardableResult
    public func enqueue(_ log: SetLog, at timestamp: Date = Date()) throws -> Int {
        try store.appendPendingLog(log, sourceDevice: .watch, at: timestamp)
        return try store.readPendingLogs().count
    }

    public func pending() throws -> [PendingSetLog] {
        try store.readPendingLogs()
    }

    public func pendingCount() throws -> Int {
        try store.readPendingLogs().count
    }

    /// 传输层报错时把日志放回队列。
    ///
    /// `transferUserInfo` 只保证「已交给系统排队」，不保证「已送达对端」；
    /// 真正的结果在 `didFinishUserInfoTransfer` 的 error 里。如果不管它，
    /// 那条组日志在 flush 时就已经从队列删掉了——用户以为记上了，实际没有。
    public func requeue(_ entry: PendingSetLog) throws {
        try store.requeuePendingLog(entry)
    }

    /// 超过 24 小时还没送出去，UI 该提示用户打开 iPhone。
    public func needsUserAlert(now: Date = Date()) throws -> Bool {
        let entries = try store.readPendingLogs()
        guard let oldest = entries.map(\.timestamp).min() else { return false }
        return now.timeIntervalSince(oldest) >= LogRetryScheduler.alertAfter
    }

    public func flush(
        using sender: any PendingLogSending,
        now: Date = Date()
    ) async -> PendingLogFlushOutcome {
        guard !isSending else { return .busy }
        guard scheduler.canAttempt(now: now) else {
            return .backingOff(until: scheduler.nextAttemptAt ?? now)
        }

        let entries: [PendingSetLog]
        do {
            entries = try store.readPendingLogs()
        } catch {
            return .failed(sent: 0, remaining: 0, retryAfter: scheduler.recordFailure(now: now))
        }
        guard !entries.isEmpty else {
            scheduler.recordSuccess()
            return .empty
        }

        isSending = true
        defer { isSending = false }

        var sent: [PendingSetLog] = []
        for entry in entries {
            do {
                try await sender.send(entry)
                sent.append(entry)
            } catch {
                if !sent.isEmpty {
                    try? store.removePendingLogs { sent.contains($0) }
                }
                let delay = scheduler.recordFailure(now: now)
                let remaining = (try? store.readPendingLogs().count) ?? max(0, entries.count - sent.count)
                return .failed(sent: sent.count, remaining: remaining, retryAfter: delay)
            }
        }

        try? store.removePendingLogs { sent.contains($0) }
        scheduler.recordSuccess()
        return .sent(sent.count)
    }
}
