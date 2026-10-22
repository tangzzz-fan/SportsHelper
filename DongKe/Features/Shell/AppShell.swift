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

    init() {
        #if DEBUG
        let preview = ProcessInfo.processInfo.environment["DK_PREVIEW"] ?? ""
        let dayIndex = SampleData.trainingDayIndex(for: Date())
        switch preview {
        case "workout":
            _session = State(initialValue: WorkoutSession(plan: SampleData.plan, dayIndex: dayIndex))
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
                    PlaceholderScreen(title: "计划", subtitle: "下周排期与计划导入")
                case .history:
                    PlaceholderScreen(title: "记录", subtitle: "周完成率与连续天数")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            TabIsland(selection: $tab)
                .padding(.bottom, 24)
        }
        .fullScreenCover(item: $session) { active in
            WorkoutView(session: active) {
                session = nil
            }
        }
    }

    private func startWorkout() {
        session = WorkoutSession(plan: SampleData.plan, dayIndex: SampleData.trainingDayIndex(for: Date()))
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

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
