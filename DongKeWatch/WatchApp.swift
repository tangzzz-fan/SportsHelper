import SwiftUI

@main
struct DongKeWatchApp: App {
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
