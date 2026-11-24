import Foundation
import WatchConnectivity
import DongKeCore

struct WatchLogSender: PendingLogSending {
    func send(_ entry: PendingSetLog) async throws {
        let session = WCSession.default
        guard session.activationState == .activated else {
            throw WatchLogSenderError.sessionNotActive
        }
        let data = try JSONEncoder().encode(entry)
        session.transferUserInfo([WatchSyncKey.log: data])
    }
}

enum WatchLogSenderError: Error {
    case sessionNotActive
}
