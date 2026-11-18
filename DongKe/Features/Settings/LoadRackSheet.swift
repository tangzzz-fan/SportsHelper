import SwiftUI
import DongKeCore

/// 第一次练负重动作时问一次：家里的重量是可调的还是固定档位。
/// 问过之后不再自动弹，设置页里还能改。
struct LoadRackSheet: View {
    var onSave: (LoadRack) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var kind: LoadRack.Kind
    @State private var step: Double
    @State private var useFixedSet: Bool

    init(initial: LoadRack = LoadRackStore.shared.rack, onSave: @escaping (LoadRack) -> Void = { _ in }) {
        self.onSave = onSave
        _kind = State(initialValue: initial.kind)
        _step = State(initialValue: initial.kind == .adjustable ? max(2.5, initial.step) : 2.5)
        _useFixedSet = State(initialValue: initial.kind == .fixed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("加量时要给出你买得到的重量。你家里的哑铃是哪种？")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        choice(
                            title: "可调哑铃 / 壶铃",
                            subtitle: "一次能加固定的一档，比如 2.5kg 或 5kg",
                            selected: kind == .adjustable
                        ) {
                            kind = .adjustable
                            useFixedSet = false
                        }
                        .accessibilityIdentifier(A11y.Settings.rackAdjustable)

                        Divider().overlay(Color.primary.opacity(0.06)).padding(.leading, 16)

                        choice(
                            title: "固定档位",
                            subtitle: "只有买回来的那几个重量，比如 4 / 6 / 8 / 10kg",
                            selected: kind == .fixed
                        ) {
                            kind = .fixed
                            useFixedSet = true
                        }
                        .accessibilityIdentifier(A11y.Settings.rackFixed)
                    }
                    .glassSurface(radius: Theme.Radius.glassCard)

                    if kind == .adjustable {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("一次能加多少")
                                .font(Typography.meta)
                                .foregroundStyle(.secondary)
                            Picker("一次能加多少", selection: $step) {
                                Text("2.5kg").tag(2.5)
                                Text("5kg").tag(5.0)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier(A11y.Settings.rackStep)
                        }
                    }

                    if kind == .fixed {
                        Text(LoadRack.fixedDumbbells.detail)
                            .font(Typography.meta)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("只存本机，不上报。练的时候仍然可以随时手动调重量。")
                        .font(Typography.meta)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("重量档位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(selectedRack)
                        dismiss()
                    }
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .accessibilityIdentifier(A11y.Settings.rackSave)
                }
            }
        }
    }

    private var selectedRack: LoadRack {
        switch kind {
        case .adjustable:
            return LoadRack(kind: .adjustable, step: step)
        case .fixed:
            return .fixedDumbbells
        }
    }

    private func choice(
        title: String,
        subtitle: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Typography.rowTitle)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent(for: colorScheme) : Color.secondary.opacity(0.5))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableGlassStyle())
    }
}
