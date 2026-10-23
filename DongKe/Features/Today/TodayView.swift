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
    private let settingsStore = ReminderSettingsStore.shared
    @Environment(NotificationService.self) private var notifications

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
        #if DEBUG
        initial = ProcessInfo.processInfo.environment["DK_PREVIEW"] == "settings"
        #endif
        _showSettings = State(initialValue: initial)
    }

    @Environment(\.colorScheme) var colorScheme
    @Environment(SessionStore.self) var store

    var today: PlanDay? {
        let weekday = SampleData.weekday(for: Date())
        if let day = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay }) {
            return day
        }
        return nextTrainingDay
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

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: Icons.settings)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Theme.accent(for: colorScheme))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)

                Text("今日")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.horizontal, 16)

                Text(dateLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)

                if reminderHealth.needsAttention {
                    reminderBanner(reminderHealth)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
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

                Spacer()
            }
            .padding(.top, 4)
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
        .task {
            await notifications.refreshStatus()
        }
    }

    private func requestAuthorization() {
        Task {
            await notifications.requestAuthorization()
            await notifications.reschedule(plan: plan, settings: settingsStore.settings)
        }
    }

    private func reminderBanner(_ health: ReminderHealth) -> some View {
        HStack(spacing: 10) {
            Text(health.message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(health.actionTitle) {
                handleReminderAction(health)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent(for: colorScheme))
            .frame(minHeight: 44)
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
