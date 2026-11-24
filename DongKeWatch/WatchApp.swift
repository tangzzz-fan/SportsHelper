import SwiftUI

@main
struct DongKeWatchApp: App {
    init() {
        // 通知的 didReceive 可能早于 WindowGroup 的 task，
        // delegate 必须在这里就位，否则第一次点通知收不到。
        MainActor.assumeIsolated {
            WatchNotificationHandler.shared.activate()
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .task {
                    WatchContextModel.shared.loadFromCache()
                    WatchSyncService.shared.activate()
                }
        }
    }
}
