import Foundation
import Observation
import WatchConnectivity
import DongKeCore

@MainActor
@Observable
final class WatchContextModel {
    static let shared = WatchContextModel()

    private(set) var context: WatchContext?

    func loadFromCache() {
        context = try? WatchContextStore.shared.load()
    }

    func update(_ context: WatchContext) {
        self.context = context
        try? WatchContextStore.shared.save(context)
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
        guard let data = payload[WatchSyncKey.context] as? Data,
              let context = try? JSONDecoder().decode(WatchContext.self, from: data)
        else {
            return
        }
        Task { @MainActor in
            WatchContextModel.shared.update(context)
        }
    }
}
