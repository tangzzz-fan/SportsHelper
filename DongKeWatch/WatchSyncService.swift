import Foundation
import Observation
import WatchConnectivity
import DongKeCore

@MainActor
@Observable
final class WatchContextModel {
    static let shared = WatchContextModel()

    private(set) var context: WatchContext?
    private(set) var planRevision: Int?

    func loadFromCache() {
        context = try? WatchContextStore.shared.load()
    }

    func update(_ context: WatchContext) {
        self.context = context
        try? WatchContextStore.shared.save(context)
    }

    func updatePlanRevision(_ revision: Int) {
        planRevision = revision
    }
}

final class WatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncService()

    private let pendingQueue = PendingLogQueue(store: .live)

    private override init() {
        super.init()
        WCSession.default.delegate = self
    }

    func activate() {
        guard WCSession.default.activationState != .activated else { return }
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        apply(session.receivedApplicationContext)
        // 冷启动就把积压补发出去：用户很可能上次是在断连状态下练完、
        // 锁屏、再也没打开过 Watch App，那一组日志一直躺在 outbox 里。
        let queue = pendingQueue
        Task {
            _ = await queue.flush(using: WatchLogSender(), now: Date())
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        apply(applicationContext)
    }

    /// 系统接手组日志之后的最终结果。
    ///
    /// `transferUserInfo` 的返回值只说明「已交给系统排队」，真正的成败在这里。
    /// 失败时必须把 payload 原样放回队列——`flush` 那时已经把这条从 outbox 删了，
    /// 不补回去这条日志就永久消失了（用户手上是「已同步」，iPhone 上什么都没有）。
    /// 成功不用做事：iPhone 侧 `addIfAbsent` 已经落库。
    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        guard error != nil,
              let data = userInfoTransfer.userInfo[WatchSyncKey.log] as? Data,
              let entry = try? JSONDecoder().decode(PendingSetLog.self, from: data)
        else { return }

        let queue = pendingQueue
        Task {
            try? await queue.requeue(entry)
            _ = await queue.flush(using: WatchLogSender(), now: Date())
        }
    }

    private nonisolated func apply(_ payload: [String: Any]) {
        let context = (payload[WatchSyncKey.context] as? Data)
            .flatMap { try? JSONDecoder().decode(WatchContext.self, from: $0) }
        let revision = (payload[WatchSyncKey.planRevision] as? Int)
            ?? (payload[WatchSyncKey.planRevision] as? NSNumber)?.intValue

        guard context != nil || revision != nil else { return }
        Task { @MainActor in
            if let context {
                WatchContextModel.shared.update(context)
            }
            if let revision {
                WatchContextModel.shared.updatePlanRevision(revision)
            }
        }
    }
}
