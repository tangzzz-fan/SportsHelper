import SwiftUI
import DongKeCore

struct SettingsSheet: View {
    @Bindable var settingsStore: ReminderSettingsStore
    let plan: WorkoutPlan
    var onRequestAuthorization: () -> Void
    var onReschedule: () -> Void

    @Environment(NotificationService.self) private var notifications
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    reminderCard
                    statusCard
                    AISettingsCard()
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.accent(for: colorScheme))
                }
            }
        }
    }

    private var reminderCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("训练提醒")
                        .font(.system(size: 16, weight: .medium))
                    Text("按计划在训练日提前提醒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { settingsStore.settings.enabled },
                    set: { newValue in
                        settingsStore.settings.enabled = newValue
                        onReschedule()
                    }
                ))
                .labelsHidden()
                .tint(Theme.accent(for: colorScheme))
            }
            .padding(16)

            Divider().overlay(Color.primary.opacity(0.06)).padding(.leading, 16)

            HStack {
                Text("提前")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Picker("提前", selection: Binding(
                    get: { settingsStore.settings.leadMinutes },
                    set: { newValue in
                        settingsStore.settings.leadMinutes = newValue
                        onReschedule()
                    }
                )) {
                    Text("5 分钟").tag(5)
                    Text("10 分钟").tag(10)
                    Text("15 分钟").tag(15)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(16)
            .opacity(settingsStore.settings.enabled ? 1 : 0.45)
            .disabled(!settingsStore.settings.enabled)
        }
        .glassSurface(radius: Theme.Radius.card)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("通知权限")
                    .font(.system(size: 15))
                Spacer()
                Text(notifications.statusText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(notifications.status == .denied ? Color.red : Theme.accent(for: colorScheme))
            }

            HStack {
                Text("已排程提醒")
                    .font(.system(size: 15))
                Spacer()
                Text("\(notifications.scheduledCount) 条")
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
            }

            if notifications.status == .notDetermined {
                Button {
                    onRequestAuthorization()
                } label: {
                    Text("开启通知权限")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PressableGlassStyle())
                .foregroundStyle(Theme.callToActionInk(for: colorScheme))
                .background(
                    Theme.accent(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                )
                .padding(.top, 4)
            }

            Text("单计划最多 7 条周重复触发器；修改计划后会先清空旧提醒再重排，不会叠加。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
    }
}
