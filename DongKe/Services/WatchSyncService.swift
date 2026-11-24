import Foundation
import WatchConnectivity
import DongKeCore
import os

private let watchLog = Logger(subsystem: "app.dongke.ios", category: "watch-sync")

/// iPhone → Watch 的上下文出口。只发 `WatchContext` 的 JSON；
/// 队列与重发由 WCSession 自己负责，这里只保留最后一份，激活后再补发。
final class WatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncService()

    private let session: WCSession?
    private let lock = NSLock()
    private var latestContext: Data?

    private override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
    }

    func activate() {
        guard let session, session.activationState != .activated else { return }
        session.activate()
    }

    func send(_ context: WatchContext) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        lock.lock()
        latestContext = data
        lock.unlock()
        push(data)
    }

    private nonisolated func push(_ data: Data) {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext([WatchSyncKey.context: data])
            watchLog.debug("watch context sent bytes=\(data.count)")
        } catch {
            watchLog.error("watch context send failed: \(String(describing: error), privacy: .public)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        lock.lock()
        let data = latestContext
        lock.unlock()
        if let data {
            push(data)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
