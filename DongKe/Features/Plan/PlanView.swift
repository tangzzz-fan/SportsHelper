import SwiftUI
import DongKeCore

struct PlanView: View {
    let plan: WorkoutPlan

    @Environment(\.colorScheme) private var colorScheme
    @Environment(PlanStore.self) private var planStore
    @Environment(NotificationService.self) private var notifications
    @State private var showLibrary = false
    @State private var showImport = false
    @State private var showAI = false
    @State private var selectedDay: PlanDay?

    init(plan: WorkoutPlan) {
        self.plan = plan
        #if DEBUG
        let preview = ProcessInfo.processInfo.environment["DK_PREVIEW"] ?? ""
        _showLibrary = State(initialValue: preview == "library" || preview == "detail" || preview == "myexercise")
        _showImport = State(initialValue: preview == "import")
        #endif
    }

    private var weeks: [(weekday: Weekday, day: PlanDay?)] {
        Weekday.allCases.map { weekday in
            (weekday, plan.days.first(where: { $0.weekday == weekday }))
        }
    }

    private var todayWeekday: Weekday {
        SampleData.weekday(for: Date())
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.15, y: 0.1),
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("计划")
                        .font(Typography.pageTitle)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .accessibilityIdentifier(A11y.Plan.title)

                    Text(plan.meta.title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    VStack(spacing: 0) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, entry in
                            row(entry.weekday, entry.day)
                            if index < weeks.count - 1 {
                                Divider()
                                    .overlay(Color.primary.opacity(0.06))
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .glassSurface(radius: Theme.Radius.glassCard)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    Text("每周 \(plan.meta.daysPerWeek) 天 · 每次 \(plan.meta.sessionMinutes) 分钟 · \(ExerciseLibrary.all.count) 个动作")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    aiEntry
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    HStack(spacing: 10) {
                        entryButton(title: "动作库", symbol: Icons.library) {
                            showLibrary = true
                        }
                        entryButton(title: "导入计划", symbol: Icons.importPlan) {
                            showImport = true
                        }
                        .accessibilityIdentifier(A11y.Plan.importPlan)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.bottom, 96, for: .scrollContent)
        }
        .sheet(isPresented: $showLibrary) {
            ExerciseLibraryView { showLibrary = false }
        }
        .sheet(item: $selectedDay) { day in
            PlanDayDetailView(day: day)
        }
        .sheet(isPresented: $showAI) {
            QuickAIPlanSheet { saved in
                planStore.save(saved)
                showAI = false
                Task {
                    if notifications.status == .authorized || notifications.status == .provisional {
                        await notifications.reschedule(
                            plan: saved,
                            settings: ReminderSettingsStore.shared.settings
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showImport) {
            ImportView { imported in
                planStore.save(imported)
                showImport = false
                Task {
                    if notifications.status == .authorized || notifications.status == .provisional {
                        await notifications.reschedule(
                            plan: imported,
                            settings: ReminderSettingsStore.shared.settings
                        )
                    }
                }
            }
        }
    }

    private var aiEntry: some View {
        Button {
            showAI = true
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("说一句，让 AI 排计划")
                        .font(Typography.rowTitle)
                        .foregroundStyle(.primary)
                    Text("例如：最近肩颈不适，每周三次，每次 30 分钟，有哑铃")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: Icons.disclosure)
                    .font(Typography.capsLabel)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableGlassStyle())
        .glassSurface(radius: Theme.Radius.card)
        .accessibilityIdentifier(A11y.Plan.aiEntry)
    }

    private func entryButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(Typography.secondary.weight(.medium))
                Text(title)
                    .font(Typography.secondary.weight(.medium))
            }
            .foregroundStyle(Theme.accent(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(PressableGlassStyle())
        .glassSurface(radius: Theme.Radius.card)
    }

    private func row(_ weekday: Weekday, _ day: PlanDay?) -> some View {
        let isToday = weekday == todayWeekday
        let isTraining = !(day?.isRestDay ?? true)
        return Button {
            selectedDay = day
        } label: {
            HStack(spacing: 12) {
                Text(weekday.chineseName)
                    .font(Typography.secondary.weight(isToday ? .semibold : .regular))
                    .foregroundStyle(isToday ? Theme.accent(for: colorScheme) : .secondary)
                    .frame(minWidth: 44, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)

                Circle()
                    .fill(isTraining ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.15))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    Text(day?.title ?? "休息")
                        .font(Typography.rowTitle.weight(isTraining ? .medium : .regular))
                        .foregroundStyle(isTraining ? .primary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let time = day?.scheduledTime, isTraining {
                        Text(String(format: "%02d:%02d · 约 %d 分钟", time.hour, time.minute, day?.estimatedMinutes ?? 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if isToday {
                    Text("今天")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.halo(for: colorScheme), in: Capsule())
                }

                if day != nil {
                    Image(systemName: Icons.disclosure)
                        .font(Typography.capsLabel)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(PressableGlassStyle())
        .disabled(day == nil)
        .accessibilityIdentifier("\(A11y.Plan.dayRow).\(weekday.rawValue)")
        .accessibilityHint(day?.isRestDay == true ? "休息日" : "查看当天动作")
    }
}
