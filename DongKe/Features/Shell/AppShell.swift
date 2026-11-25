import SwiftUI
import DongKeCore

struct AppShell: View {
    enum Tab: String, CaseIterable {
        case today = "今日"
        case plan = "计划"
        case history = "记录"
    }

    @State private var tab: Tab = .today
    @State private var session: WorkoutSession?
    @Environment(SessionStore.self) private var store
    @Environment(SetLogStore.self) private var setLogs
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PlanStore.self) private var planStore
    @Bindable private var deload = DeloadStore.shared
    @State private var resumeCandidate: WorkoutCheckpoint?
    private let checkpoints = WorkoutCheckpointStore()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if let preview = AppShellPreview.make() {
            if let session = preview.session {
                _session = State(initialValue: session)
            }
            if let tab = preview.tab {
                _tab = State(initialValue: tab)
            }
        }
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            Group {
                switch tab {
                case .today:
                    TodayView(
                        plan: activePlan,
                        onStart: startWorkout,
                        onStartShort: startShort,
                        resumeHint: resumeHint,
                        onResume: resumeWorkout,
                        onEraseAll: handleEraseAll,
                        deloadNote: deloadNote
                    )
                case .plan:
                    PlanView(plan: activePlan, isDeloadWeek: deloadNote != nil)
                case .history:
                    HistoryView(weeklyTarget: weeklyTarget)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            TabIsland(selection: $tab)
                .padding(.bottom, 24)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_ERASE_ALL"] == "1" {
                await DataResetService.clearAll(context: modelContext)
            }
            if ProcessInfo.processInfo.environment["DK_REQUEST_PROVISIONAL"] == "1" {
                await NotificationService.shared.requestProvisionalForTesting()
            }
            #endif
            await NotificationService.shared.refreshStatus()
            NotificationService.shared.router.onOpenWorkout = { link in
                openWorkout(link)
            }
            // 手表发来的意图先走这里：有视图时用户就在 iPhone 上，能直接看到训练页。
            // App 被后台唤起时这个闭包没人注册，inbox 会自己落盘并广播。
            WatchIntentInbox.shared.liveLauncher = { intent in
                let launch = resolve(intent)
                apply(launch, persistNow: true)
                return launch
            }
            #if DEBUG
            // 模拟器上没法配对 Watch，用它验证「收到意图 → 裁决 → 落盘」这条链。
            // 只在状态真的变了的时候有意义：restart 会把断点换成新会话。
            if let raw = ProcessInfo.processInfo.environment["DK_WATCH_INTENT"] {
                let stored = checkpoints.load()
                let dayIndex = stored?.dayIndex
                    ?? PlanCalendar.occurrence(on: Date(), in: activePlan)?.dayIndex
                if let dayIndex {
                    _ = WatchIntentInbox.shared.handle(
                        WatchIntent(
                            kind: raw == "restart" ? .restart : .start,
                            dayIndex: dayIndex,
                            sessionId: stored?.sessionId,
                            planRevision: activePlan.revision
                        )
                    )
                }
            }
            #endif
            #if DEBUG
            // 通知回调没法在模拟器上点（本地通知没有可注入的 response），
            // 用这个钩子直接走同一个入口，验证「点通知会不会覆盖正在进行的进度」。
            if let raw = ProcessInfo.processInfo.environment["DK_OPEN_REMINDER"],
               let day = Int(raw) {
                openWorkout(.dayIndex(day))
            }
            #endif
            if NotificationService.shared.status == .authorized || NotificationService.shared.status == .provisional {
                await NotificationService.shared.reschedule(
                    plan: activePlan,
                    settings: ReminderSettingsStore.shared.settings
                )
            }
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_RESET_PROFILE"] == "1" {
                profileStore.reset()
            }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_SEED_SESSION"] == "1", store.sessions.isEmpty {
                // 记录页要有多条才有说服力：一周三次、完成率各不相同。
                let seed: [(String, Int, Int)] = [
                    ("下肢力量", 12, 12),
                    ("上肢与核心", 11, 11),
                    ("下肢力量", 12, 10),
                    ("上肢与核心", 11, 11),
                    ("下肢力量", 12, 12),
                ]
                for (index, item) in seed.enumerated() {
                    let day = Calendar.current.startOfDay(for: Date())
                        .addingTimeInterval(-Double(index * 2 + 1) * 86_400)
                        .addingTimeInterval(20 * 3600 + 30 * 60)
                    store.upsert(
                        id: UUID(),
                        title: item.0,
                        plannedSets: item.1,
                        completedSets: item.2,
                        startedAt: day,
                        finishedAt: day.addingTimeInterval(28 * 60)
                    )
                }
            }
            // 记录页的「手表」标签：靠它验证 origin 落库与读取，模拟器配不了真表。
            if ProcessInfo.processInfo.environment["DK_SEED_WATCH_SESSION"] == "1" {
                let start = Date().addingTimeInterval(-1_800)
                store.upsert(
                    id: UUID(),
                    title: "上肢与核心",
                    plannedSets: 11,
                    completedSets: 11,
                    startedAt: start,
                    finishedAt: start.addingTimeInterval(25 * 60),
                    origin: .watch
                )
            }
            #endif
        }
        .fullScreenCover(item: $session) { active in
            WorkoutView(session: active) {
                session = nil
                refreshResumeCandidate()
            }
            .onAppear {
                // DK_PREVIEW=workout 会绕过 start() 直接造会话，这里补一次依赖注入。
                active.setLogStore = setLogs
                active.store = store
                active.preloadLastLoads()
            }
        }
        .onAppear {
            refreshResumeCandidate()
            WatchLogInbox.shared.setLogStore = setLogs
            WatchLogInbox.shared.session = session
            WatchLogInbox.shared.drain()
            WatchSyncService.shared.setPlanRevision(activePlan.revision)
        }
        .onChange(of: session?.id) { _, _ in
            WatchLogInbox.shared.session = session
            WatchLogInbox.shared.drain()
        }
        .onChange(of: activePlan.revision) { _, revision in
            WatchSyncService.shared.setPlanRevision(revision)
            refreshResumeCandidate()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            WatchLogInbox.shared.drain()
        }
    }

    /// 计划本来的样子。减载周只改显示与当次训练，不改它。
    private var rawPlan: WorkoutPlan {
        ActivePlanProvider.raw(planStore: planStore, profileStore: profileStore)
    }

    /// 第 4 周目标值 ×0.6。不写回计划、不改 revision，第 5 周自动恢复。
    private var activePlan: WorkoutPlan {
        ActivePlanProvider.current(
            planStore: planStore,
            profileStore: profileStore,
            deloadEnabled: deload.isEnabled
        )
    }

    private var deloadNote: String? {
        guard let startedAt = rawPlan.createdAt else { return nil }
        let week = DeloadWeek.weekIndex(on: Date(), startedAt: startedAt)
        return DeloadWeek.note(enabled: deload.isEnabled, weekIndex: week)
    }

    private var weeklyTarget: Int {
        activePlan.meta.weeklyTarget(skipped: DaySkipStore.shared.skippedThisWeek())
    }

    private func openWorkout(_ link: WorkoutDeepLink) {
        let plan = activePlan
        let dayIndex: Int?
        switch link {
        case let .dayIndex(index):
            dayIndex = plan.days.first(where: { $0.dayIndex == index && !$0.isRestDay })?.dayIndex
        case let .weekday(weekday):
            dayIndex = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay })?.dayIndex
        }
        guard let dayIndex else { return }
        tab = .today
        apply(resolve(.openReminder(dayIndex: dayIndex)))
    }

    private func startWorkout() {
        apply(resolve(.startToday))
    }

    /// 今天只剩 N 分钟：把这一节压短，只影响这次会话，不改计划、不改 revision。
    private func startShort(minutes: Int) {
        let launch = resolve(.startToday)
        guard case let .create(dayIndex, _) = launch else {
            apply(launch)
            return
        }
        let plan = activePlan
        guard let day = plan.days.first(where: { $0.dayIndex == dayIndex }) else { return }
        var shortPlan = plan
        if let index = shortPlan.days.firstIndex(where: { $0.dayIndex == dayIndex }) {
            shortPlan.days[index] = SessionCompressor.compress(day, toMinutes: minutes)
        }
        LocalCounters.shared.increment(.shortSessionStarted)
        start(
            dayIndex: dayIndex,
            on: PlanCalendar.occurrence(of: dayIndex, anchoredAt: Date(), in: plan)?.date,
            in: shortPlan,
            kind: .short
        )
    }

    private func resolve(_ intent: SessionIntent) -> SessionLaunch {
        SessionLaunchResolver.resolve(
            intent: intent,
            active: activeSession,
            stored: checkpoints.load(),
            plan: activePlan,
            now: Date()
        )
    }

    /// 内存里正在练的那一次。
    ///
    /// 还没记过组的会话没有断点，所以单独用 `ActiveSession` 表达；
    /// 拿 checkpoint 顶替会让裁决器把「已经开始了」当成「什么都没有」，于是再建一个。
    private var activeSession: ActiveSession? {
        guard let session else { return nil }
        return ActiveSession(
            id: session.id,
            dayIndex: session.dayIndex,
            startedAt: session.startedAt,
            checkpoint: session.snapshot()
        )
    }

    /// `persistNow` 用于手表发起的意图：那边已经开始记组了，断点必须立刻落盘，
    /// 否则一次都没记的会话在 iPhone 上没有痕迹，日志回来时找不到归属。
    private func apply(_ launch: SessionLaunch, persistNow: Bool = false) {
        switch launch {
        case .open:
            // 已经是当前会话了，什么都不做。重建一次会把进度条和播报状态清掉，
            // 那正是「点通知进度归零」的表面症状。
            break
        case let .resume(checkpoint):
            resumeInto(checkpoint)
        case let .create(dayIndex, origin):
            let plan = activePlan
            let created = start(
                dayIndex: dayIndex,
                on: PlanCalendar.occurrence(of: dayIndex, anchoredAt: Date(), in: plan)?.date,
                in: plan,
                origin: origin
            )
            if persistNow { created.saveCheckpoint() }
        case let .abandonAndCreate(abandoned, dayIndex, origin):
            discard(abandoned)
            let plan = activePlan
            let created = start(
                dayIndex: dayIndex,
                on: PlanCalendar.occurrence(of: dayIndex, anchoredAt: Date(), in: plan)?.date,
                in: plan,
                origin: origin
            )
            if persistNow { created.saveCheckpoint() }
        case .blocked:
            break
        }
    }

    @discardableResult
    private func start(
        dayIndex: Int,
        on planDate: Date?,
        in plan: WorkoutPlan,
        kind: SessionKind = .full,
        origin: SessionOrigin = .phone
    ) -> WorkoutSession {
        let active = WorkoutSession(
            plan: plan,
            dayIndex: dayIndex,
            planDate: planDate,
            kind: kind,
            origin: origin
        )
        active.store = store
        active.setLogStore = setLogs
        active.checkpointStore = checkpoints
        active.restNotifications = NotificationService.shared
        active.preloadLastLoads()
        session = active
        return active
    }

    private func resumeWorkout() {
        guard let checkpoint = resumeCandidate else { return }
        resumeInto(checkpoint)
    }

    private func resumeInto(_ checkpoint: WorkoutCheckpoint) {
        LocalCounters.shared.increment(.checkpointResumed)
        let plan = activePlan
        let occurrence = PlanCalendar.occurrence(
            of: checkpoint.dayIndex,
            anchoredAt: checkpoint.startedAt,
            in: plan
        )
        let active = WorkoutSession(
            plan: plan,
            dayIndex: checkpoint.dayIndex,
            planDate: occurrence?.date,
            origin: nil,
            store: store,
            startedAt: checkpoint.startedAt,
            id: checkpoint.sessionId,
            checkpoint: checkpoint
        )
        active.setLogStore = setLogs
        active.checkpointStore = checkpoints
        active.restNotifications = NotificationService.shared
        active.preloadLastLoads()
        resumeCandidate = nil
        session = active
    }

    /// 放弃一次会话：两处断点都清掉，内存里是它就一起收。
    /// 已经记过的组留在日志库里不动——那几组确实做了，只是这次没练完。
    private func discard(_ sessionId: UUID) {
        checkpoints.clear()
        try? CheckpointStore.shared.remove(sessionId: sessionId)
        if session?.id == sessionId {
            session = nil
        }
        resumeCandidate = nil
    }

    private func handleEraseAll() {
        session = nil
        resumeCandidate = nil
        profileStore.load()
        planStore.load()
        store.reload()
        ReminderSettingsStore.shared.reload()
        AISettingsStore.shared.reloadFromDisk()
    }

    private func refreshResumeCandidate() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_SEED_CHECKPOINT"] == "1", checkpoints.load() == nil {
            let plan = activePlan
            let dayIndex = plan.days.first(where: { !$0.isRestDay })?.dayIndex ?? 1
            let flow = WorkoutFlowModel(plan: plan, dayIndex: dayIndex)
            let now = Date()
            checkpoints.save(WorkoutCheckpoint(
                sessionId: UUID(),
                dayIndex: dayIndex,
                stepIndex: min(3, max(0, flow.steps.count - 2)),
                totalSteps: flow.steps.count,
                startedAt: now.addingTimeInterval(-420),
                updatedAt: now,
                revision: plan.revision
            ))
        }
        #endif
        let stored = checkpoints.load()
        guard let stored else {
            resumeCandidate = nil
            return
        }
        let validation = CheckpointValidator.validate(
            stored,
            currentPlanRevision: activePlan.revision,
            now: Date()
        )
        guard validation == .resumable else {
            // 过期才计一次窗口信号；计划改版不是「窗口太短」，不能污染这个计数。
            if validation == .expired {
                LocalCounters.shared.increment(.checkpointExpired)
            }
            checkpoints.clear()
            try? CheckpointStore.shared.remove(sessionId: stored.sessionId)
            resumeCandidate = nil
            return
        }
        resumeCandidate = stored
    }

    private var resumeHint: String? {
        guard let checkpoint = resumeCandidate else { return nil }
        let title = activePlan.days.first(where: { $0.dayIndex == checkpoint.dayIndex })?.title ?? "上次训练"
        let step = min(checkpoint.stepIndex + 1, checkpoint.totalSteps)
        return "\(title) · 停在第 \(step)/\(checkpoint.totalSteps) 步"
    }
}

private struct TabIsland: View {
    @Binding var selection: AppShell.Tab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppShell.Tab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.footnote.weight(selection == tab ? .semibold : .regular))
                        .foregroundStyle(selection == tab ? Theme.accent(for: colorScheme) : Color.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background {
                            if selection == tab {
                                Capsule().fill(Color.primary.opacity(0.06))
                            }
                        }
                }
                .buttonStyle(PressableGlassStyle())
            }
        }
        .padding(4)
        .glassSurface(radius: Theme.Radius.glassIsland)
    }
}
