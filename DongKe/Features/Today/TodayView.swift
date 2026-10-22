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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(SessionStore.self) private var store

    private var today: PlanDay? {
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
                        Image(systemName: "gearshape")
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

    private var backgroundLayer: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.85, y: 0.32),
                startRadius: 0,
                endRadius: 320
            )

            if let catalogId = today?.blocks.first?.items.first?.catalogId {
                ExerciseFigureView(catalogId: catalogId,
                                   figureSize: CGSize(width: 320, height: 372),
                                   showsHalo: false)
                    .opacity(0.08)
                    .rotationEffect(.degrees(-4))
                    .offset(x: 78, y: 96)
            }
        }
        .ignoresSafeArea()
    }

    private var isRestToday: Bool {
        let weekday = SampleData.weekday(for: Date())
        guard let day = plan.days.first(where: { $0.weekday == weekday }) else { return true }
        return day.isRestDay
    }

    private func resumeCard(_ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("上次训练没做完")
                .font(.system(size: 16, weight: .semibold))
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(action: onResume) {
                Text("继续训练")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.accent(for: colorScheme).opacity(0.35), lineWidth: 1)
            )
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func sessionCard(_ day: PlanDay) -> some View {
        let items = day.blocks.flatMap(\.items)
        let resting = isRestToday
        return VStack(alignment: .leading, spacing: 12) {
            Text(resting ? "今天休息" : day.title)
                .font(.system(size: 22, weight: .semibold))

            Text(resting
                 ? "下次训练 \(day.weekday.chineseName) \(timeText(day)) · \(items.count) 个动作"
                 : "\(items.count) 个动作 · 约 \(day.estimatedMinutes) 分钟 · \(timeText(day))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Text("本周")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.completedThisWeek) / \(plan.meta.daysPerWeek)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                ProgressBar(progress: min(1, Double(store.completedThisWeek) / Double(max(1, plan.meta.daysPerWeek))))
            }
            .padding(.top, 12)

            Button(action: onStart) {
                Text(isRestToday ? "提前练一次" : "开始训练")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                Theme.accent(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.52), .white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .padding(.top, 12)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private var nextTrainingDay: PlanDay? {
        let training = plan.days.filter { !$0.isRestDay }
        guard !training.isEmpty else { return nil }
        let today = SampleData.weekday(for: Date()).rawValue
        return training.first(where: { $0.weekday.rawValue > today }) ?? training.first
    }

    private func timeText(_ day: PlanDay) -> String {
        guard let time = day.scheduledTime else { return "—" }
        return String(format: "%02d:%02d", time.hour, time.minute)
    }
}

struct ProgressBar: View {
    var progress: Double
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SessionStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Theme.accent(for: colorScheme))
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 4)
    }
}
