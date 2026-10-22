import SwiftUI
import DongKeCore

struct SettingsSheet: View {
    @Bindable var settingsStore: ReminderSettingsStore
    let plan: WorkoutPlan
    var onRequestAuthorization: () -> Void
    var onReschedule: () -> Void
    var onEraseAll: () -> Void = {}

    @Environment(NotificationService.self) private var notifications
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var showEraseConfirm = false
    @State private var isErasing = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        reminderCard
                        statusCard
                        AISettingsCard()
                        aboutCard
                        dangerCard
                    }
                    .padding(16)
                }
                .onAppear {
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["DK_SETTINGS_BOTTOM"] == "1" {
                        proxy.scrollTo("settings.bottom", anchor: .bottom)
                    }
                    #endif
                }
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
            .confirmationDialog(
                "清空后训练记录、计划、档案、我的动作与 API Key 都会删除，无法恢复。",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("清空全部数据", role: .destructive, action: eraseAll)
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("关于")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Text(versionText)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text("动刻把 AI 写的计划变成每天按点提醒、逐组执行的日程。数据只存本机，不联网也能用；唯一的网络出口是你自己填的 AI 接口。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.card)
    }

    private var dangerCard: some View {
        Button {
            showEraseConfirm = true
        } label: {
            HStack {
                Text(isErasing ? "清空中…" : "清空全部数据")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Theme.danger(for: colorScheme))
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableGlassStyle())
        .glassSurface(radius: Theme.Radius.card)
        .disabled(isErasing)
        .id("settings.bottom")
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func eraseAll() {
        guard isErasing == false else { return }
        isErasing = true
        Task {
            await DataResetService.clearAll(context: modelContext)
            isErasing = false
            dismiss()
            onEraseAll()
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
