import Foundation
import SwiftUI
import DongKeCore

enum WatchRoute: Hashable {
    case workout(sessionId: UUID)
}

struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [WatchRoute] = []
    @State private var model = WatchContextModel.shared
    @State private var session = WatchWorkoutSession()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let context = model.context {
                    WatchWorkoutView(session: session, context: context)
                } else {
                    WatchEmptyView()
                }
            }
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case let .workout(sessionId):
                    WatchWorkoutPlaceholderView(sessionId: sessionId)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { date in
            session.tick(now: date)
        }
        .onChange(of: model.context) { _, context in
            guard let context else { return }
            session.sync(with: context)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            session.tick(now: Date())
            session.refreshPending()
            session.flushPending()
        }
        .task {
            WatchContextModel.shared.loadFromCache()
            WatchSyncService.shared.activate()
            if let context = model.context {
                session.sync(with: context)
            }
            session.refreshPending()
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_WATCH_DEMO_REST"] == "1" {
                session.startRest(seconds: 90)
            }
            #endif
        }
    }
}

private struct WatchEmptyView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("动刻")
                .font(.headline)
            Text("请在 iPhone 上开始训练")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct WatchWorkoutPlaceholderView: View {
    let sessionId: UUID

    var body: some View {
        Text("训练页建设中")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
