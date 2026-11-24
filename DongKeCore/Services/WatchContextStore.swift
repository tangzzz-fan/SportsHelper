import Foundation

/// Watch 侧的本地上下文缓存。收包后落盘，冷启动先读缓存再等新包。
public struct WatchContextStore: Sendable {
    public static let shared = WatchContextStore(store: .live)

    private let store: AppGroupsStore

    public init(store: AppGroupsStore) {
        self.store = store
    }

    public func save(_ context: WatchContext) throws {
        try store.saveWatchContext(context)
    }

    public func load() throws -> WatchContext? {
        try store.loadWatchContext()
    }

    public func remove() throws {
        try store.removeWatchContext()
    }
}
