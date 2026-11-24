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
    private var latestPlanRevision: Int?

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
        push()
    }

    /// 计划 revision 变化时单独下发。applicationContext 只保留 planRevision 也没关系：
    /// Watch 的上下文在本地磁盘，收不到 context 时继续用缓存。
    func setPlanRevision(_ revision: Int) {
        lock.lock()
        let changed = latestPlanRevision != revision
        latestPlanRevision = revision
        lock.unlock()
        guard changed else { return }
        push()
    }

    private nonisolated func push() {
        guard let session, session.activationState == .activated else { return }
        lock.lock()
        let context = latestContext
        let revision = latestPlanRevision
        lock.unlock()

        var payload: [String: Any] = [:]
        if let context {
            payload[WatchSyncKey.context] = context
        }
        if let revision {
            payload[WatchSyncKey.planRevision] = revision
        }
        guard !payload.isEmpty else { return }

        do {
            try session.updateApplicationContext(payload)
            watchLog.debug("watch sync sent revision=\(revision ?? -1) bytes=\(context?.count ?? 0)")
        } catch {
            watchLog.error("watch sync send failed: \(String(describing: error), privacy: .public)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        push()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        if let intent = Self.decodeIntent(userInfo[WatchSyncKey.intent]) {
            // 排队送达的路径没有回执通道，手表那边靠「上下文变了」或 8 秒超时收场。
            Task { @MainActor in
                WatchIntentInbox.shared.handle(intent)
            }
            return
        }
        guard let data = userInfo[WatchSyncKey.log] as? Data,
              let entry = try? JSONDecoder().decode(PendingSetLog.self, from: data)
        else {
            return
        }
        do {
            try AppGroupsStore.live.appendPendingLog(
                entry.log,
                sourceDevice: entry.sourceDevice,
                at: entry.timestamp
            )
            watchLog.debug("watch log received set=\(entry.log.setIndex)")
            Task { @MainActor in
                WatchLogInbox.shared.drain()
            }
        } catch {
            watchLog.error("watch log store failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// 手表就在附近时走这条：有回执，等待态能立刻结束。
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let intent = Self.decodeIntent(message[WatchSyncKey.intent]) else { return }
        // WCSession 的回调签名没有并发标注，回执要在主 actor 上构造完再发出去。
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            let ack = WatchIntentInbox.shared.handle(intent)
            guard let data = try? JSONEncoder().encode(ack) else { return }
            reply([WatchSyncKey.intentAck: data])
        }
    }

    private nonisolated static func decodeIntent(_ raw: Any?) -> WatchIntent? {
        guard let data = raw as? Data else { return nil }
        return try? JSONDecoder().decode(WatchIntent.self, from: data)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
