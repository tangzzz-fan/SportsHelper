import SwiftUI
import UIKit
import DongKeCore

struct PlanEditRow: Identifiable {
    var dayIndex: Int
    var itemId: String
    var name: String
    var originalName: String
    var catalogId: String
    var isDuration: Bool
    var sets: Int
    var value: Int
    var restSec: Int

    var id: String { "\(dayIndex)-\(itemId)" }
}


struct PlanReviewView: View {
    let draft: ParsedPlanDraft
    @State private var plan: WorkoutPlan
    var onSave: (WorkoutPlan) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(UserExerciseStore.self) private var userExercises
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PlanStore.self) private var planStore
    @Environment(SetLogStore.self) private var setLogStore
    @State private var editing: PlanEditRow?
    @State private var soreParts: Set<BodyPart> = []
    /// 只有用户自己勾了才加版本号：导入往往只是同一份计划的小修，
    /// 自动加会让老用户重开 App 时看到计划自己变了（revision 同时是重排种子）。
    @State private var isNewVersion = false
    private let memo = AliasMemoStore()
    private let corrections = CorrectionStore()

    init(draft: ParsedPlanDraft, plan: WorkoutPlan, onSave: @escaping (WorkoutPlan) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _plan = State(initialValue: plan)
    }

    private var trainingDays: [PlanDay] {
        plan.days.filter { !$0.isRestDay }
    }

    private var previousPlan: WorkoutPlan? {
        planStore.plan
    }

    private var diff: PlanDiff {
        guard let previousPlan else { return PlanDiff() }
        return PlanDiff.compare(
            old: previousPlan,
            new: plan,
            painCatalogIds: Set(setLogStore.recentLogs().filter { $0.skipReason == .pain }.compactMap(\.catalogId))
        )
    }

    private var planToSave: WorkoutPlan {
        guard isNewVersion, let previousPlan else { return plan }
        return plan.markingSource(plan.source, revision: previousPlan.revision + 1)
    }

    private var diffCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("和上一版比")
                .font(Typography.cardTitle)

            ForEach(diff.lines) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text(label(for: line.kind))
                        .font(Typography.capsLabel)
                        .foregroundStyle(color(for: line.kind))
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.text)
                            .font(Typography.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(line.day)
                            .font(Typography.meta)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if diff.painful.isEmpty == false {
                Text("上一版里 \(diff.painful.joined(separator: "、")) 标过疼，这一版还在。")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
        .accessibilityIdentifier(A11y.Import.diffCard)
    }

    private var newVersionToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("这是上一份的新版本")
                    .font(Typography.rowTitle)
                Text("勾了版本号加一，旧记录按版本对上；不勾就当成另一份计划。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isNewVersion)
                .labelsHidden()
                .tint(Theme.accent(for: colorScheme))
                .accessibilityIdentifier(A11y.Import.newVersionToggle)
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
    }

    private func label(for kind: PlanDiff.Kind) -> String {
        switch kind {
        case .added: "新增"
        case .removed: "换下"
        case .changed: "调整"
        }
    }

    private func color(for kind: PlanDiff.Kind) -> Color {
        switch kind {
        case .added: Theme.accent(for: colorScheme)
        case .removed: .secondary
        case .changed: .secondary
        }
    }

    private var blocking: [ParseIssue] {
        draft.issues.filter { $0.severity == .error }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                PlanOriginNotice(source: plan.source)

                if diff.isEmpty == false {
                    diffCard
                }

                if previousPlan != nil {
                    newVersionToggle
                }

                if !blocking.isEmpty {
                    PlanIssueBanner(issues: blocking)
                }

                if draft.assumptions.isEmpty == false {
                    assumptionsCard
                }

                PlanSorePicker(soreParts: $soreParts)

                if soreParts.isEmpty == false {
                    PlanSafetyCard(
                        issues: safetyIssues,
                        reliefs: safetyReliefs,
                        plan: plan,
                        soreParts: soreParts
                    )
                }

                ForEach(trainingDays) { day in
                    dayCard(day)
                }

                if trainingDays.isEmpty {
                    Text("这份计划里没有训练日，回到上一页重新粘贴，或者手动添加。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(PlanSafetyChecker.disclaimer)
                    .font(Typography.capsLabel)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(A11y.Import.medicalNotice)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("校对")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            soreParts = BodyPartDetector.parts(in: profileStore.profile?.injuries ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    onSave(planToSave)
                }
                .font(Typography.buttonLabel)
                .foregroundStyle(Theme.accent(for: colorScheme))
                .disabled(blocking.isEmpty == false)
                .accessibilityIdentifier(A11y.Import.save)
            }
        }
        .sheet(item: $editing) { row in
            EditRowSheet(
                row: row,
                myExercises: userExercises.all,
                onApply: { result in
                    if let catalogId = result.catalogId,
                       catalogId != row.catalogId || draft.guessedItems[row.itemId] != nil {
                        memo.remember(row.originalName, catalogId: catalogId)
                    }
                    let effectiveCatalog = result.catalogId ?? row.catalogId
                    if result.sets != row.sets {
                        corrections.remember(catalogId: effectiveCatalog, field: .sets, to: result.sets)
                    }
                    if result.value != row.value {
                        corrections.remember(catalogId: effectiveCatalog, field: .value, to: result.value)
                    }
                    if result.saveAsMine {
                        userExercises.add(UserExercise(
                            name: row.originalName,
                            group: result.group,
                            equipment: UserExercise.inferEquipment(fromName: row.originalName),
                            isStatic: row.isDuration,
                            defaultSets: result.sets,
                            defaultValue: result.value,
                            restSec: result.rest
                        ))
                    }
                    plan = PlanEditing.updateItem(
                        in: plan,
                        dayIndex: row.dayIndex,
                        itemId: row.itemId,
                        sets: result.sets,
                        value: result.value,
                        restSec: result.rest,
                        catalogId: result.catalogId
                    )
                    editing = nil
                },
                onCancel: { editing = nil }
            )
            .presentationDetents([.height(560)])
            .presentationBackground(.regularMaterial)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.meta.title)
                .font(Typography.detailTitle)
            Text("\(trainingDays.count) 个训练日 · \(pathText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var pathText: String {
        switch draft.path {
        case .strictJSON: "按 JSON 严格解析"
        case .lenientJSON: "按 JSON 补齐后解析"
        case .freeText: "按文字识别"
        case .blank: "未识别"
        }
    }

    private var assumptionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("我替你判断了这些，请核对")
                .font(.footnote.weight(.semibold))
            ForEach(Array(draft.assumptions.prefix(6).enumerated()), id: \.offset) { _, line in
                Text("· \(line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if draft.assumptions.count > 6 {
                Text("还有 \(draft.assumptions.count - 6) 条已按同样规则处理")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.halo(for: colorScheme).opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var safetyIssues: [SafetyIssue] {
        PlanSafetyChecker.check(plan, soreParts: soreParts)
    }

    private var safetyReliefs: [ExerciseEntry] {
        PlanSafetyChecker.reliefs(for: soreParts)
    }

    private func dayCard(_ day: PlanDay) -> some View {
        let items = day.blocks.flatMap(\.items)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(day.weekday.chineseName) · \(day.title)")
                    .font(Typography.cardTitle)
                Spacer()
                Text("约 \(day.estimatedMinutes) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        let original = draft.guessedItems[item.itemId]?.originalName ?? item.name
                        editing = PlanEditRow(
                            dayIndex: day.dayIndex,
                            itemId: item.itemId,
                            name: original,
                            originalName: original,
                            catalogId: item.catalogId,
                            isDuration: item.target.type == .durationSec,
                            sets: item.sets,
                            value: item.target.value,
                            restSec: item.restSec
                        )
                    } label: {
                        itemRow(item)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
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
        let guess = draft.guessedItems[item.itemId]
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(guess?.originalName ?? item.name)
                    .font(Typography.secondary.weight(.medium))
                    .foregroundStyle(.primary)
                Text(doseText(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if let guess {
                Text(guess.isMemory ? "上次记为\(guess.catalogName)" : "按\(guess.catalogName)计入")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(guess.isMemory ? Theme.accent(for: colorScheme) : .orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        (guess.isMemory ? Theme.accent(for: colorScheme) : Color.orange).opacity(0.12),
                        in: Capsule()
                    )
            } else if userExercises.exercise(for: item.catalogId) != nil {
                Text("我的动作")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.accent(for: colorScheme).opacity(0.12), in: Capsule())
            } else if ExerciseLibrary.entry(for: item.catalogId) == nil {
                Text("不在库里")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
            Image(systemName: Icons.edit)
                .font(Typography.meta.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func doseText(_ item: ExercisePrescription) -> String {
        let perSide = item.target.perSide ? " / 侧" : ""
        return "\(item.sets) 组 × \(item.target.doseText)\(perSide) · 休息 \(item.restSec) 秒"
    }
}
