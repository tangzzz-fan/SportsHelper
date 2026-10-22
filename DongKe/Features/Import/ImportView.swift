import SwiftUI
import DongKeCore

private struct PlanEditRow: Identifiable {
    var dayIndex: Int
    var itemId: String
    var name: String
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

    @State private var text = ""
    @State private var draft: ParsedPlanDraft?
    @State private var showReview = false
    @State private var autoParsed = false

    private static let sampleText = """
    周一 深蹲 4组×12次，休息90秒
    俯卧撑 3组×10次，休息60秒
    平板支撑 3组 每组30秒，休息45秒

    周四 箭步蹲 3组 每侧12次，休息60秒
    臀桥 3组×15次，休息60秒
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
        let parsed = PlanImportService.parse(text)
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
    @State private var editing: PlanEditRow?

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
                onApply: { sets, value, rest in
                    plan = PlanEditing.updateItem(
                        in: plan,
                        dayIndex: row.dayIndex,
                        itemId: row.itemId,
                        sets: sets,
                        value: value,
                        restSec: rest
                    )
                    editing = nil
                },
                onCancel: { editing = nil }
            )
            .presentationDetents([.height(400)])
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
                        editing = PlanEditRow(
                            dayIndex: day.dayIndex,
                            itemId: item.itemId,
                            name: item.name,
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(doseText(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
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

private struct EditRowSheet: View {
    let row: PlanEditRow
    var onApply: (Int, Int, Int) -> Void
    var onCancel: () -> Void

    @State private var sets: Int
    @State private var value: Int
    @State private var rest: Int

    init(row: PlanEditRow, onApply: @escaping (Int, Int, Int) -> Void, onCancel: @escaping () -> Void) {
        self.row = row
        self.onApply = onApply
        self.onCancel = onCancel
        _sets = State(initialValue: row.sets)
        _value = State(initialValue: row.value)
        _rest = State(initialValue: row.restSec)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Text(row.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("应用") { onApply(sets, value, rest) }
                    .fontWeight(.semibold)
            }
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

            Spacer()
        }
    }
}
