import Foundation
import DongKeCore

/// iPhone 侧的 Watch 日志入口。原则：**先进 SwiftData，再清 App Group**。
/// 没有活跃会话时直接落 `SetLogStore`；有会话时交给会话账本，
/// 会话不存在同一键时才算消费成功。
@MainActor
final class WatchLogInbox {
    static let shared = WatchLogInbox()

    weak var session: WorkoutSession?
    weak var setLogStore: SetLogStore?

    private let store = AppGroupsStore.live
    private(set) var lastIngestedCount = 0

    func drain() {
        guard let entries = try? store.readPendingLogs(), !entries.isEmpty else {
            return
        }

        var consumed: [PendingSetLog] = []
        for entry in entries {
            if let session, session.id == entry.log.sessionId {
                if session.ingestRemoteLog(entry.log) {
                    consumed.append(entry)
                }
            } else if let setLogStore {
                if setLogStore.addIfAbsent(entry.log) {
                    consumed.append(entry)
                }
            }
        }

        guard !consumed.isEmpty else { return }
        try? store.removePendingLogs { consumed.contains($0) }
        lastIngestedCount += consumed.count
    }
}
