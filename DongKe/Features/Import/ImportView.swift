import SwiftUI
import UIKit
import DongKeCore

struct ImportView: View {
    var onSave: (WorkoutPlan) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(UserExerciseStore.self) private var userExercises
    @Environment(ProfileStore.self) private var profiles

    @State private var text = ""
    @State private var draft: ParsedPlanDraft?
    @State private var showReview = false
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
        if let pasted = ProcessInfo.processInfo.environment["DK_IMPORT_PASTE"] {
            _text = State(initialValue: pasted)
        } else if ProcessInfo.processInfo.environment["DK_IMPORT_SAMPLE"] == "1" {
            _text = State(initialValue: Self.sampleText)
        }
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("粘贴训练计划")
                        .font(Typography.detailTitle)
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
                    .accessibilityIdentifier(A11y.Import.parse)

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
                            Image(systemName: copiedPrompt ? Icons.copied : Icons.copy)
                                .font(Typography.meta.weight(.medium))
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
        }
    }

    private var canParse: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("把计划粘贴到这里…")
                    .font(Typography.secondary)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
            TextEditor(text: $text)
                .font(Typography.monoInput)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 200)
                .accessibilityIdentifier(A11y.Import.editor)
        }
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func failureTitle(_ draft: ParsedPlanDraft) -> String {
        if draft.issues.contains(where: { $0.message.contains("没粘完整") }) {
            return "这段内容没粘完整"
        }
        if draft.issues.contains(where: { $0.message.contains("内容太多") || $0.message.contains("64KB") }) {
            return "内容太多了"
        }
        return draft.path == .lenientJSON ? "这段 JSON 结构不对" : "没能识别出动作"
    }

    private func failureCard(_ draft: ParsedPlanDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(failureTitle(draft))
                .font(Typography.cardTitle)
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
