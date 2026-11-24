import Foundation
import SwiftUI
import os
import DongKeCore

private let watchLog = Logger(subsystem: "app.dongke.ios", category: "watch")

enum WatchRoute: Hashable {
    case workout(sessionId: UUID)
}

struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [WatchRoute] = []
    @State private var model = WatchContextModel.shared
    @State private var session = WatchWorkoutSession()
    @State private var notifications = WatchNotificationHandler.shared

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let context = model.context {
                    WatchWorkoutView(
                        session: session,
                        context: context,
                        planRevision: model.planRevision
                    )
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
        .onChange(of: notifications.openedDayIndex) { _, dayIndex in
            guard let dayIndex else { return }
            notifications.consumeOpenedDay()
            // App 有快照时本来就是训练页，所以这里不需要「路由」到别处；
            // 记下通知说的是哪天、快照是哪天，真机验收靠这条日志确认链路通没通。
            // 计划改版的阻断由 WatchWorkoutView 里的 CheckpointValidator 兜（W2.5）。
            watchLog.notice(
                "notification open day=\(dayIndex, privacy: .public) contextDay=\(model.context?.checkpoint.dayIndex ?? -1, privacy: .public)"
            )
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
