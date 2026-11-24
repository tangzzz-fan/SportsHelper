import Foundation
import WatchConnectivity
import DongKeCore

/// 手表 → iPhone 的意图出口。
///
/// 可达时用 `sendMessage` 拿即时回执（「重新开始」的等待态靠它），不可达时
/// 排 `transferUserInfo` 等 iPhone 回来。两条路都可能到达，所以意图本身必须
/// 幂等——`SessionLaunchResolver` 靠 `sessionId` 保证。
final class WatchIntentSender: @unchecked Sendable {
    static let shared = WatchIntentSender()

    private let session = WCSession.default

    func send(_ intent: WatchIntent, completion: (@MainActor (WatchIntentAck?) -> Void)? = nil) {
        guard let data = try? JSONEncoder().encode(intent) else {
            Task { @MainActor in completion?(nil) }
            return
        }
        let payload: [String: Any] = [WatchSyncKey.intent: data]
        guard session.activationState == .activated, session.isReachable else {
            queue(payload, completion: completion)
            return
        }
        session.sendMessage(payload) { reply in
            let ack = Self.decodeAck(reply)
            Task { @MainActor in completion?(ack) }
        } errorHandler: { _ in
            self.queue(payload, completion: completion)
        }
    }

    /// 排队送达没有回执，等待态交给调用方的超时收场。
    private func queue(_ payload: [String: Any], completion: (@MainActor (WatchIntentAck?) -> Void)?) {
        guard session.activationState == .activated else {
            Task { @MainActor in completion?(nil) }
            return
        }
        session.transferUserInfo(payload)
        Task { @MainActor in completion?(nil) }
    }

    private static func decodeAck(_ reply: [String: Any]) -> WatchIntentAck? {
        guard let data = reply[WatchSyncKey.intentAck] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchIntentAck.self, from: data)
    }
}
