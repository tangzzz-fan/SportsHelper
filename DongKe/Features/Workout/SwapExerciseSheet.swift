import SwiftUI
import DongKeCore

/// 训练中换动作。只换这次剩下的组，不改计划、不改版本。
/// 列表最多 3 个：这是「现在没法做，换个能做的」，不是重新挑动作。
struct SwapExerciseSheet: View {
    let currentName: String
    let candidates: [ExerciseEntry]
    var onPick: (ExerciseEntry) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("换掉「\(currentName)」剩下的组。已经做完的照旧记在 \(currentName) 名下，剂量也算它。")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, entry in
                            Button {
                                onPick(entry)
                                dismiss()
                            } label: {
                                row(entry)
                            }
                            .buttonStyle(PressableGlassStyle())
                            .accessibilityIdentifier(A11y.Workout.swapOption(entry.id))

                            if index < candidates.count - 1 {
                                Divider()
                                    .overlay(Color.primary.opacity(0.06))
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .glassSurface(radius: Theme.Radius.glassCard)
                    .padding(.horizontal, 16)

                    Text("换动作只影响这次训练。想长期换，练完在计划页点「调整」。")
                        .font(Typography.meta)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("换个动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.accent(for: colorScheme))
                }
            }
        }
    }

    private func row(_ entry: ExerciseEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(Typography.rowTitle)
                    .foregroundStyle(.primary)
                Text(subtitle(entry))
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func subtitle(_ entry: ExerciseEntry) -> String {
        var parts = ["\(entry.group.title) · \(entry.equipment.chineseName)"]
        if entry.cues.isEmpty == false, let cue = entry.cues.first {
            parts.append(cue)
        }
        return parts.joined(separator: " · ")
    }
}
