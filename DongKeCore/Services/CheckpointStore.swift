import Foundation

/// 会话快照的跨进程入口。iPhone 写、Watch 读（经 WatchConnectivity 传输后落到各自容器）。
///
/// 与 `DongKe/Data/WorkoutCheckpointStore` 的分工：
/// - 那个存 UserDefaults，是 iPhone 自己的断点续练，杀进程就靠它；
/// - 这个存 App Group，是给另一台设备的「交接单」，取不到容器时静默降级。
public struct CheckpointStore: Sendable {
    public static let shared = CheckpointStore(store: .live)

    private let store: AppGroupsStore

    public init(store: AppGroupsStore) {
        self.store = store
    }

    public var isAvailable: Bool {
        store.isAvailable
    }

    public func save(_ checkpoint: WorkoutCheckpoint) throws {
        try store.saveCheckpoint(checkpoint)
    }

    public func load(sessionId: UUID) throws -> WorkoutCheckpoint? {
        try store.loadCheckpoint(sessionId: sessionId)
    }

    public func remove(sessionId: UUID) throws {
        try store.removeCheckpoint(sessionId: sessionId)
    }
}
