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
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PlanStore.self) private var planStore
    @State private var showingOnboarding = false

    init() {
        #if DEBUG
        let preview = ProcessInfo.processInfo.environment["DK_PREVIEW"] ?? ""
        let dayIndex = SampleData.trainingDayIndex(for: Date())
        switch preview {
        case "workout":
            _session = State(initialValue: WorkoutSession(plan: SampleData.plan, dayIndex: dayIndex))
        case "plan":
            _tab = State(initialValue: .plan)
        case "history":
            _tab = State(initialValue: .history)
        case "library", "import", "detail":
            _tab = State(initialValue: .plan)
        case "summary":
            let active = WorkoutSession(
                plan: SampleData.plan,
                dayIndex: dayIndex,
                startedAt: Date().addingTimeInterval(-22 * 60)
            )
            for _ in 0..<4 {
                active.completeSet()
                active.skipRest()
            }
            active.downgradeSet()
            active.skipRest()
            active.endWorkout()
            _session = State(initialValue: active)
        case "rest":
            let active = WorkoutSession(plan: SampleData.plan, dayIndex: dayIndex)
            active.completeSet()
            _session = State(initialValue: active)
        default:
            break
        }
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            Group {
                switch tab {
                case .today:
                    TodayView(plan: activePlan, onStart: startWorkout)
                case .plan:
                    PlanView(plan: activePlan)
                case .history:
                    HistoryView(weeklyTarget: activePlan.meta.daysPerWeek)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            TabIsland(selection: $tab)
                .padding(.bottom, 24)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_REQUEST_PROVISIONAL"] == "1" {
                await NotificationService.shared.requestProvisionalForTesting()
            }
            #endif
            await NotificationService.shared.refreshStatus()
            if NotificationService.shared.status == .authorized || NotificationService.shared.status == .provisional {
                await NotificationService.shared.reschedule(
                    plan: SampleData.plan,
                    settings: ReminderSettingsStore.shared.settings
                )
            }
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_RESET_PROFILE"] == "1" {
                profileStore.reset()
            }
            #endif
            showingOnboarding = !profileStore.hasOnboarded || ProcessInfo.processInfo.environment["DK_PREVIEW"] == "onboarding"
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_COMPLETE_ONBOARDING"] == "1", !profileStore.hasOnboarded {
                profileStore.save(OnboardingDraft().completedProfile(now: Date()))
                showingOnboarding = false
            }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.environment["DK_SEED_SESSION"] == "1", store.sessions.isEmpty {
                store.upsert(
                    id: UUID(),
                    title: SampleData.plan.days.first(where: { !$0.isRestDay })?.title ?? "训练",
                    plannedSets: 13,
                    completedSets: 13,
                    startedAt: Date(),
                    finishedAt: Date()
                )
            }
            #endif
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(initialStep: previewOnboardingStep()) { profile in
                profileStore.save(profile)
                let generated = PlanGenerator.makePlan(profile: profile)
                planStore.save(generated)
                showingOnboarding = false
                Task {
                    if profile.reminderEnabled {
                        await NotificationService.shared.requestAuthorization()
                        await NotificationService.shared.reschedule(
                            plan: generated,
                            settings: ReminderSettingsStore.shared.settings
                        )
                    }
                }
            }
        }
        .fullScreenCover(item: $session) { active in
            WorkoutView(session: active) {
                session = nil
            }
        }
    }

    private func previewOnboardingStep() -> OnboardingStep {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["DK_ONBOARD_STEP"], let value = Int(raw) {
            return OnboardingStep(rawValue: value) ?? .basics
        }
        #endif
        return .basics
    }

    private var activePlan: WorkoutPlan {
        planStore.plan ?? PlanGenerator.makePlan(profile: profileStore.profile ?? UserProfile())
    }

    private func startWorkout() {
        let plan = activePlan
        let weekday = SampleData.weekday(for: Date())
        let dayIndex = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay })?.dayIndex
            ?? plan.days.first(where: { !$0.isRestDay })?.dayIndex
            ?? 1
        let active = WorkoutSession(plan: plan, dayIndex: dayIndex)
        active.store = store
        session = active
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
