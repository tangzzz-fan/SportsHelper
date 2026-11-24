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
    /// 本次生命周期内是否还要问「接着练吗」。
    @State private var showsResumePrompt = false
    /// 已答「继续练」的会话。同一个会话只问一次。
    @State private var answeredSessionId: UUID?
    /// 已答「今天不练了」的会话。同一个会话不再显示训练页。
    @State private var declinedSessionId: UUID?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if showsResumePrompt, let context = model.context {
                    WatchResumeChoiceView(
                        set: session.currentSet(in: context),
                        onResume: { answerPrompt(for: context, resume: true) },
                        onDecline: { answerPrompt(for: context, resume: false) }
                    )
                } else if let context = model.context,
                          context.checkpoint.sessionId != declinedSessionId {
                    WatchWorkoutView(
                        session: session,
                        context: context,
                        planRevision: model.planRevision
                    )
                } else {
                    WatchEmptyView(
                        message: declinedSessionId == nil ? nil : "今天先到这儿\n断点还在，明天接着来"
                    )
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
            evaluateResumePrompt(context)
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
                evaluateResumePrompt(context)
            }
            session.refreshPending()
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_WATCH_DEMO_REST"] == "1" {
                session.startRest(seconds: 90)
            }
            #endif
        }
    }

    /// 每次上下文更新都重算一次，而不是只在首次判：用户停在选择页时
    /// iPhone 那边可能又记了一组，那时就该直接进训练页，别继续问。
    private func evaluateResumePrompt(_ context: WatchContext) {
        let id = context.checkpoint.sessionId
        guard id != answeredSessionId, id != declinedSessionId else {
            showsResumePrompt = false
            return
        }
        showsResumePrompt = ResumePrompt.shouldAsk(
            checkpoint: context.checkpoint,
            currentPlanRevision: model.planRevision,
            now: Date()
        )
    }

    private func answerPrompt(for context: WatchContext, resume: Bool) {
        if resume {
            answeredSessionId = context.checkpoint.sessionId
        } else {
            declinedSessionId = context.checkpoint.sessionId
        }
        showsResumePrompt = false
    }
}

private struct WatchEmptyView: View {
    /// 有值时替换默认那句。点过「今天不练了」会用到。
    var message: String?

    var body: some View {
        VStack(spacing: 6) {
            Text("动刻")
                .font(.headline)
            Text(message ?? "请在 iPhone 上开始训练")
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
