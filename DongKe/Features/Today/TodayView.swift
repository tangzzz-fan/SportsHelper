import SwiftUI
import UIKit
import DongKeCore

struct TodayView: View {
    let plan: WorkoutPlan
    var onStart: () -> Void
    var resumeHint: String?
    var onResume: () -> Void
    var onEraseAll: () -> Void

    @State private var showSettings: Bool
    @State var showSkipConfirm = false
    @State private var showMicroDose = false
    private let settingsStore = ReminderSettingsStore.shared
    @Bindable var daySkip = DaySkipStore.shared
    @Environment(NotificationService.self) private var notifications
    @Environment(ProfileStore.self) private var profileStore

    init(
        plan: WorkoutPlan,
        onStart: @escaping () -> Void,
        resumeHint: String? = nil,
        onResume: @escaping () -> Void = {},
        onEraseAll: @escaping () -> Void = {}
    ) {
        self.plan = plan
        self.onStart = onStart
        self.resumeHint = resumeHint
        self.onResume = onResume
        self.onEraseAll = onEraseAll
        var initial = false
        var microDoseInitial = false
        #if DEBUG
        initial = ProcessInfo.processInfo.environment["DK_PREVIEW"] == "settings"
        microDoseInitial = ProcessInfo.processInfo.environment["DK_PREVIEW"] == "microdose"
        #endif
        _showSettings = State(initialValue: initial)
        _showMicroDose = State(initialValue: microDoseInitial)
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(SessionStore.self) var store

    var today: PlanDay? {
        guard let occurrence = todayOccurrence else { return nil }
        return plan.days.first(where: { $0.dayIndex == occurrence.dayIndex })
    }

    var todayOccurrence: PlanOccurrence? {
        PlanCalendar.occurrence(on: Date(), in: plan)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 EEE"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: Icons.settings)
                                .font(Typography.body)
                                .foregroundStyle(Theme.accent(for: colorScheme))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier(A11y.Today.settings)
                    }
                    .padding(.horizontal, 8)

                    Text("今日")
                        .font(Typography.pageTitle)
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier(A11y.Today.title)

                    Text(dateLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    if reminderHealth.needsAttention {
                        reminderBanner(reminderHealth)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .accessibilityIdentifier(A11y.Today.reminderBanner)
                    }

                    if let resumeHint {
                        resumeCard(resumeHint)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    if let day = today {
                        sessionCard(day)
                            .padding(.horizontal, 16)
                            .padding(.top, 22)
                    }
                    if let next = nextTrainingDay, !isRestToday {
                        Text("下次训练 \(next.weekday.chineseName) \(timeText(next))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }

                    if let dose = microDose {
                        Button {
                            showMicroDose = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: Icons.microDose)
                                Text("三分钟活动一下 · \(dose.reason)")
                                Spacer(minLength: 8)
                                Image(systemName: Icons.disclosure)
                                    .font(Typography.micro)
                            }
                            .font(Typography.secondary)
                            .foregroundStyle(Theme.accent(for: colorScheme))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .accessibilityIdentifier(A11y.Today.microDose)
                    }

                }
                .padding(.top, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.bottom, 96, for: .scrollContent)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                settingsStore: settingsStore,
                plan: plan,
                onRequestAuthorization: requestAuthorization,
                onReschedule: rescheduleReminders,
                onEraseAll: onEraseAll
            )
        }
        .sheet(isPresented: $showMicroDose) {
            if let dose = microDose {
                MicroDoseView(dose: dose)
            }
        }
        .task {
            await notifications.refreshStatus()
        }
        .confirmationDialog(
            "今天先不练？本周目标会少一次，今天不会记成「漏练」。明天照常。",
            isPresented: $showSkipConfirm,
            titleVisibility: .visible
        ) {
            Button("今天不练") { daySkip.skip() }
                .accessibilityIdentifier(A11y.Today.skipToday)
            Button("取消", role: .cancel) {}
        }
    }

    private func requestAuthorization() {
        Task {
            await notifications.requestAuthorization()
            await notifications.reschedule(plan: plan, settings: settingsStore.settings)
        }
    }

    private var microDose: MicroDose? {
        guard let profile = profileStore.profile else { return nil }
        return MicroDosePlanner.pick(profile: profile, plan: plan, on: Date())
    }

    private func reminderBanner(_ health: ReminderHealth) -> some View {
        HStack(spacing: 10) {
            Text(health.message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                handleReminderAction(health)
            } label: {
                Text(health.actionTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        )
    }

    private func handleReminderAction(_ health: ReminderHealth) {
        switch health {
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        case .incomplete:
            rescheduleReminders()
        case .disabled, .notDetermined:
            showSettings = true
        case .ok:
            break
        }
    }

    private var reminderHealth: ReminderHealth {
        ReminderHealthEvaluator.evaluate(
            settingsEnabled: settingsStore.settings.enabled,
            authorization: notifications.reminderAuthorization,
            scheduledCount: notifications.scheduledCount,
            trainingDays: plan.days.filter { !$0.isRestDay }.count
        )
    }

    private func rescheduleReminders() {
        Task {
            await notifications.reschedule(plan: plan, settings: settingsStore.settings)
        }
    }

}
