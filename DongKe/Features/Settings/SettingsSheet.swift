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

    @Bindable private var voice = VoiceSettingsStore.shared
    @Bindable private var largeText = LargeTextStore.shared

    @State private var showEraseConfirm = false
    @State private var showHealthNotice = false
    @State private var isErasing = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        reminderCard
                        statusCard
                        voiceCard
                        largeTextCard
                        healthCard
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
                        .accessibilityIdentifier(A11y.Settings.done)
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
            .sheet(isPresented: $showHealthNotice) {
                HealthNoticeView()
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("关于")
                    .font(Typography.rowTitle)
                Spacer()
                Text(versionText)
                    .font(Typography.secondary)
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

    private var healthCard: some View {
        Button {
            showHealthNotice = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("健康提示与免责")
                        .font(Typography.rowTitle)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: Icons.disclosure)
                        .font(Typography.micro)
                        .foregroundStyle(.tertiary)
                }
                Text("计划不替代医生。AI 写的内容可能有错，练前先看一眼。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableGlassStyle())
        .glassSurface(radius: Theme.Radius.card)
        .accessibilityIdentifier(A11y.Settings.healthNoticeEntry)
    }

    private var dangerCard: some View {
        Button {
            showEraseConfirm = true
        } label: {
            HStack {
                Text(isErasing ? "清空中…" : "清空全部数据")
                    .font(Typography.rowTitle)
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
        .accessibilityIdentifier(A11y.Settings.erase)
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
                        .font(Typography.rowTitle)
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
                .accessibilityIdentifier(A11y.Settings.reminderToggle)
            }
            .padding(16)

            Divider().overlay(Color.primary.opacity(0.06)).padding(.leading, 16)

            HStack {
                Text("提前")
                    .font(Typography.rowTitle)
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

    private var largeTextCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("大字模式")
                        .font(Typography.rowTitle)
                    Text("字更大、一屏要读的东西更少；系统字号已经更大时按系统的")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $largeText.isEnabled)
                    .labelsHidden()
                    .tint(Theme.accent(for: colorScheme))
                    .accessibilityIdentifier(A11y.Settings.largeTextToggle)
                    .accessibilityLabel("大字模式")
            }
            .padding(16)
        }
        .glassSurface(radius: Theme.Radius.card)
    }

    private var voiceCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("语音提示")
                        .font(Typography.rowTitle)
                    Text("训练时念动作、组数与休息；静音键打开时不发声")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $voice.isEnabled)
                    .labelsHidden()
                    .tint(Theme.accent(for: colorScheme))
                    .accessibilityIdentifier(A11y.Settings.voiceToggle)
                    .accessibilityLabel("语音提示")
            }
            .padding(16)

            Divider()
                .padding(.leading, 16)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(VoiceService.voiceName)
                        .font(Typography.secondary)
                    Text(VoiceService.isEnhancedVoice ? "增强音色" : "默认音色 · 系统设置里可下载更自然的中文语音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    VoiceService.shared.preview()
                } label: {
                    Text("试听")
                        .font(Typography.secondary)
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(voice.isEnabled == false)
                .opacity(voice.isEnabled ? 1 : 0.4)
                .accessibilityLabel("试听当前音色")
            }
            .padding(16)
        }
        .glassSurface(radius: Theme.Radius.card)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("通知权限")
                    .font(Typography.secondary)
                Spacer()
                Text(notifications.statusText)
                    .font(Typography.secondary.weight(.medium))
                    .foregroundStyle(notifications.status == .denied ? Color.red : Theme.accent(for: colorScheme))
            }

            HStack {
                Text("已排程提醒")
                    .font(Typography.secondary)
                Spacer()
                Text("\(notifications.scheduledCount) 条")
                    .font(Typography.secondary.weight(.medium))
                    .monospacedDigit()
                    .accessibilityIdentifier(A11y.Settings.scheduledCount)
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
