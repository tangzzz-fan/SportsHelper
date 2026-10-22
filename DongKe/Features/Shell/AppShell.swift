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
                    TodayView(onStart: startWorkout)
                case .plan:
                    PlanView()
                case .history:
                    HistoryView()
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
        .fullScreenCover(item: $session) { active in
            WorkoutView(session: active) {
                session = nil
            }
        }
    }

    private func startWorkout() {
        let active = WorkoutSession(plan: SampleData.plan, dayIndex: SampleData.trainingDayIndex(for: Date()))
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
