import SwiftUI
import DongKeCore

struct PlanDayDetailView: View {
    let day: PlanDay

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ProfileStore.self) private var profileStore
    @State private var detailEntry: ExerciseEntry?

    private var items: [ExercisePrescription] {
        day.blocks.flatMap(\.items)
    }

    private var soreParts: Set<BodyPart> {
        BodyPartDetector.parts(in: profileStore.profile?.injuries ?? "")
    }

    private var safetyIssues: [SafetyIssue] {
        PlanSafetyChecker.check(day, soreParts: soreParts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if day.isRestDay || items.isEmpty {
                        restCard
                    } else {
                        ForEach(day.blocks) { block in
                            blockCard(block)
                        }
                    }

                    if !day.notes.isEmpty {
                        Text(day.notes)
                            .font(Typography.meta)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    if !soreParts.isEmpty, day.isRestDay == false {
                        Text(PlanSafetyChecker.disclaimer)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                            .accessibilityIdentifier(A11y.Plan.safetyNotice)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(backgroundLayer)
            .navigationTitle("\(day.weekday.chineseName) · \(day.title)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { detailEntry != nil },
                set: { if !$0 { detailEntry = nil } }
            )) {
                if let entry = detailEntry {
                    ExerciseDetailView(entry: entry)
                        .navigationTitle(entry.name)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .accessibilityIdentifier(A11y.Plan.dayDetailDone)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var backgroundLayer: some View {
        ZStack {
            Theme.halo(for: colorScheme).opacity(0.5)
                .ignoresSafeArea()
            Color.clear
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if day.isRestDay {
                Text("这天用来恢复，不安排动作。")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    if let time = day.scheduledTime {
                        Text(String(format: "%02d:%02d", time.hour, time.minute))
                            .monospacedDigit()
                    } else {
                        Text("时间未定")
                    }
                    Text("·")
                    Text("约 \(day.estimatedMinutes) 分钟")
                        .monospacedDigit()
                    Text("·")
                    Text("\(items.count) 个动作")
                }
                .font(Typography.meta)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var restCard: some View {
        HStack(spacing: 10) {
            Text("休息")
                .font(Typography.cardTitle)
            Spacer()
            Text("不排动作")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func blockCard(_ block: ExerciseBlock) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(block.title)
                    .font(Typography.cardTitle)
                Spacer()
                if block.rounds > 1 {
                    Text("\(block.rounds) 轮")
                        .font(Typography.capsLabel)
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.halo(for: colorScheme), in: Capsule())
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(block.items.enumerated()), id: \.element.id) { index, item in
                    itemRow(item)
                    if index < block.items.count - 1 {
                        Divider()
                            .overlay(Color.primary.opacity(0.06))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func itemRow(_ item: ExercisePrescription) -> some View {
        let entry = ExerciseLibrary.entry(for: item.catalogId)
        let issue = safetyIssues.first { $0.itemId == item.itemId }
        return Button {
            detailEntry = entry
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Typography.secondary.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(doseText(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if let issue {
                        safetyLine(issue)
                    }
                }
                Spacer(minLength: 8)
                if entry == nil {
                    Text("自定义")
                        .font(Typography.capsLabel)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                } else {
                    Image(systemName: Icons.disclosure)
                        .font(Typography.capsLabel)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PressableGlassStyle())
        .disabled(entry == nil)
        .accessibilityIdentifier("\(A11y.Plan.itemRow).\(item.itemId)")
    }

    private func doseText(_ item: ExercisePrescription) -> String {
        let perSide = item.target.perSide ? " / 侧" : ""
        return "\(item.sets) 组 × \(item.target.doseText)\(perSide) · 休息 \(item.restSec) 秒"
    }

    private func safetyLine(_ issue: SafetyIssue) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: Icons.mistake)
                .font(Typography.capsLabel)
            Text(safetyText(issue))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption2)
        .foregroundStyle(.orange)
        .padding(.top, 1)
    }

    private func safetyText(_ issue: SafetyIssue) -> String {
        if let alternative = issue.alternativeName {
            return "\(issue.partText)吃力，可换\(alternative)"
        }
        if let lighter = issue.regressionName {
            return "\(issue.partText)吃力，可降阶为\(lighter)"
        }
        return "\(issue.partText)吃力，建议减量"
    }
}
