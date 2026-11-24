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
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        apply(applicationContext)
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
