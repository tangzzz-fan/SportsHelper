import SwiftUI
import UIKit
import DongKeCore

private struct PlanEditRow: Identifiable {
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

struct ImportView: View {
    var onSave: (WorkoutPlan) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(UserExerciseStore.self) private var userExercises
    @Environment(ProfileStore.self) private var profiles

    @State private var text = ""
    @State private var draft: ParsedPlanDraft?
    @State private var showReview = false
    @State private var autoParsed = false
    @State private var copiedPrompt = false
    private let memo = AliasMemoStore()

    private static let sampleText = """
    增肌计划 第一周
    周一 深蹲 4组×12次，休息90秒
    保加利亚分腿蹲 3组 每侧10次
    农夫行走 3组 40米

    周四 平板支撑 3组 每组45秒，休息45秒
    臀桥 3组×15次
    """

    init(onSave: @escaping (WorkoutPlan) -> Void) {
        self.onSave = onSave
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_IMPORT_SAMPLE"] == "1" {
            _text = State(initialValue: Self.sampleText)
        }
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("粘贴训练计划")
                        .font(.system(size: 22, weight: .semibold))
                    Text("支持一段文字（「周一 深蹲 4组×12次，休息90秒」）或计划的 JSON。识别后先在下一页校对再保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    editor

                    Button(action: parse) {
                        Text("识别")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .foregroundStyle(Theme.callToActionInk(for: colorScheme))
                    .background(
                        Theme.accent(for: colorScheme).opacity(canParse ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .disabled(!canParse)

                    if let draft, draft.plan == nil {
                        failureCard(draft)
                    }

                    AIGenerateCard { generated in
                        draft = generated
                        showReview = true
                    }

                    Button {
                        UIPasteboard.general.string = AIPromptBuilder.copyablePrompt(
                            profile: profiles.profile ?? UserProfile()
                        )
                        copiedPrompt = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: copiedPrompt ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                            Text(copiedPrompt ? "提示词已复制，粘给任意 AI" : "复制提示词，让 AI 按这个格式输出")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .glassSurface(radius: Theme.Radius.card)

                    Text("示例：周一 深蹲 4组×12次，休息90秒 → 周五 平板支撑 3组 每组30秒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("导入计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showReview) {
                if let draft, let plan = draft.plan {
                    PlanReviewView(draft: draft, plan: plan) { saved in
                        onSave(saved)
                        dismiss()
                    }
                }
            }
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.environment["DK_IMPORT_SAMPLE"] == "1", !autoParsed {
                    autoParsed = true
                    parse()
                }
                #endif
            }
        }
    }

    private var canParse: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("把计划粘贴到这里…")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            TextEditor(text: $text)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 200)
        }
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func failureCard(_ draft: ParsedPlanDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.path == .lenientJSON ? "这段 JSON 结构不对" : "没能识别出动作")
                .font(.system(size: 16, weight: .semibold))
            ForEach(draft.issues.filter { $0.severity == .error }) { issue in
                Text("· \(issue.message)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: startManual) {
                Text("手动添加动作")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func parse() {
        let parsed = PlanImportService.parse(text, memory: memo.load(), exercises: userExercises.catalog)
        draft = parsed
        if parsed.plan != nil {
            showReview = true
        }
    }

    private func startManual() {
        let fallback = PlanGenerator.makePlan(profile: UserProfile())
        draft = ParsedPlanDraft(plan: fallback, issues: [], rawText: text, path: .freeText)
        showReview = true
    }
}

struct PlanReviewView: View {
    let draft: ParsedPlanDraft
    @State private var plan: WorkoutPlan
    var onSave: (WorkoutPlan) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(UserExerciseStore.self) private var userExercises
    @State private var editing: PlanEditRow?
    private let memo = AliasMemoStore()

    init(draft: ParsedPlanDraft, plan: WorkoutPlan, onSave: @escaping (WorkoutPlan) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _plan = State(initialValue: plan)
    }

    private var trainingDays: [PlanDay] {
        plan.days.filter { !$0.isRestDay }
    }

    private var blocking: [ParseIssue] {
        draft.issues.filter { $0.severity == .error }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !blocking.isEmpty {
                    issueBanner
                }

                if draft.assumptions.isEmpty == false {
                    assumptionsCard
                }

                ForEach(trainingDays) { day in
                    dayCard(day)
                }

                if trainingDays.isEmpty {
                    Text("这份计划里没有训练日，回到上一页重新粘贴，或者手动添加。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("校对")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    onSave(plan)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent(for: colorScheme))
                .disabled(blocking.isEmpty == false)
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
                .font(.system(size: 22, weight: .semibold))
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

    private var issueBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("有 \(blocking.count) 处需要先改掉")
                .font(.footnote.weight(.semibold))
            ForEach(blocking) { issue in
                Text("· \(issue.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dayCard(_ day: PlanDay) -> some View {
        let items = day.blocks.flatMap(\.items)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(day.weekday.chineseName) · \(day.title)")
                    .font(.system(size: 16, weight: .semibold))
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
                    .font(.system(size: 15, weight: .medium))
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
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func doseText(_ item: ExercisePrescription) -> String {
        let unit = item.target.type == .durationSec ? "秒" : "次"
        let perSide = item.target.perSide ? " / 侧" : ""
        return "\(item.sets) 组 × \(item.target.value) \(unit)\(perSide) · 休息 \(item.restSec) 秒"
    }
}

private struct EditRowResult {
    var sets: Int
    var value: Int
    var rest: Int
    var catalogId: String?
    var saveAsMine: Bool
    var group: ExerciseGroup
}

private struct EditRowSheet: View {
    let row: PlanEditRow
    let myExercises: [UserExercise]
    var onApply: (EditRowResult) -> Void
    var onCancel: () -> Void

    @State private var sets: Int
    @State private var value: Int
    @State private var rest: Int
    @State private var catalogId: String?
    @State private var saveAsMine = false
    @State private var group: ExerciseGroup = .lower

    init(
        row: PlanEditRow,
        myExercises: [UserExercise],
        onApply: @escaping (EditRowResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.row = row
        self.myExercises = myExercises
        self.onApply = onApply
        self.onCancel = onCancel
        _sets = State(initialValue: row.sets)
        _value = State(initialValue: row.value)
        _rest = State(initialValue: row.restSec)
        _catalogId = State(initialValue: ExerciseLibrary.entry(for: row.catalogId) == nil ? nil : row.catalogId)
    }

    private var isKnown: Bool {
        ExerciseLibrary.entry(for: row.catalogId) != nil || myExercises.contains { $0.id == row.catalogId }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Text(row.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("应用") {
                    onApply(EditRowResult(
                        sets: sets,
                        value: value,
                        rest: rest,
                        catalogId: catalogId,
                        saveAsMine: saveAsMine,
                        group: group
                    ))
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Picker("动作", selection: $catalogId) {
                Text("保留原名「\(row.name)」").tag(String?.none)
                ForEach(ExerciseLibrary.all) { entry in
                    Text("\(entry.name)（\(entry.equipment.chineseName)）").tag(String?.some(entry.id))
                }
                if myExercises.isEmpty == false {
                    Section("我的动作") {
                        ForEach(myExercises) { exercise in
                            Text(exercise.name).tag(String?.some(exercise.id))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Stepper("组数  \(sets)", value: $sets, in: 1...20)
                .padding(.horizontal, 16)
                .padding(.top, 22)

            Stepper(
                row.isDuration ? "每组 \(value) 秒" : "每组 \(value) 次",
                value: $value,
                in: 1...300
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Stepper("组间休息 \(rest) 秒", value: $rest, in: 0...600, step: 15)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if isKnown == false {
                Toggle("存为我的动作", isOn: $saveAsMine)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                if saveAsMine {
                    Picker("归到", selection: $group) {
                        ForEach(ExerciseGroup.allCases, id: \.self) { group in
                            Text(group.title).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }

            Spacer()
        }
    }
}
