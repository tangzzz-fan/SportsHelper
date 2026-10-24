import SwiftUI
import DongKeCore

struct AIGenerateCard: View {
    @Binding var sentence: String
    var memory: AliasMemory
    var exercises: UserExerciseCatalog

    var onGenerated: (ParsedPlanDraft) -> Void

    @Environment(AISettingsStore.self) private var ai
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.colorScheme) private var colorScheme

    @State private var isGenerating = false
    @State private var errorText: String?
    @State private var needsKeyFix = false
    @State private var showSettings = false
    @State private var pendingSheet: BriefSheet?
    @State private var didAutoRun = false

    private struct BriefSheet: Identifiable {
        let id = UUID()
        let brief: PlanBrief
    }

    init(
        sentence: Binding<String>,
        memory: AliasMemory = .empty,
        exercises: UserExerciseCatalog = .empty,
        onGenerated: @escaping (ParsedPlanDraft) -> Void
    ) {
        _sentence = sentence
        self.memory = memory
        self.exercises = exercises
        self.onGenerated = onGenerated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("用一句话生成")
                .font(Typography.cardTitle)
            Text(canGenerate
                 ? "说一句你的想法，先核对理解，再生成计划；生成后照常在校对页改。"
                 : "先填接口地址与 API Key，才能在这里直接生成；也可以复制提示词去网页版，再把结果粘回来。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if canGenerate {
                sentenceEditor
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Theme.danger(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                if needsKeyFix {
                    Button {
                        showSettings = true
                    } label: {
                        Text("去改 Key")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent(for: colorScheme))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            action
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
        .sheet(isPresented: $showSettings) {
            AISettingsSheet()
        }
        .sheet(item: $pendingSheet) { sheet in
            BriefConfirmView(brief: sheet.brief, profile: profile) {
                pendingSheet = nil
            } onConfirm: { edited in
                pendingSheet = nil
                generate(brief: edited)
            }
        }
        .task {
            #if DEBUG
            guard didAutoRun == false else { return }
            didAutoRun = true
            let environment = ProcessInfo.processInfo.environment
            if environment["DK_BRIEF_CONFIRM"] == "1" {
                pendingSheet = BriefSheet(brief: PlanBriefParser.parse(sentence))
                return
            }
            guard environment["DK_AI_AUTOGEN"] == "1" else { return }
            generate(brief: PlanBriefParser.parse(sentence))
            #endif
        }
    }

    private var sentenceEditor: some View {
        TextField("例如：想在家增肌，每周四天，每次 40 分钟，有哑铃", text: $sentence, axis: .vertical)
            .font(Typography.body)
            .lineLimit(2...4)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .accessibilityIdentifier(A11y.Import.aiSentence)
    }

    @ViewBuilder
    private var action: some View {
        if canGenerate {
            Button(action: prepareBrief) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isGenerating ? "生成中…" : "下一步：确认理解")
                        .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                Theme.accent(for: colorScheme).opacity(isGenerating ? 0.5 : 1),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .disabled(isGenerating)
            .accessibilityIdentifier(A11y.Import.aiGenerate)
        } else {
            Button {
                showSettings = true
            } label: {
                Text("配置 AI 接口")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PressableGlassStyle())
            .glassSurface(radius: Theme.Radius.card)
        }
    }

    private var profile: UserProfile {
        profiles.profile ?? UserProfile()
    }

    private var canGenerate: Bool {
        ai.isConfigured || usesFakeAI
    }

    private var usesFakeAI: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DK_AI_FAKE"] == "1"
        #else
        false
        #endif
    }

    private func prepareBrief() {
        guard isGenerating == false else { return }
        errorText = nil
        needsKeyFix = false
        pendingSheet = BriefSheet(brief: PlanBriefParser.parse(sentence))
    }

    private func generate(brief: PlanBrief) {
        guard isGenerating == false else { return }
        isGenerating = true
        errorText = nil
        needsKeyFix = false
        let profile = self.profile
        Task {
            do {
                let draft = try await AIPlanClient().generatePlan(
                    profile: profile,
                    brief: brief,
                    memory: memory,
                    exercises: exercises
                )
                onGenerated(draft)
            } catch let error as AIClientError {
                if error == .unauthorized {
                    ai.clearKey()
                    errorText = "API Key 被拒绝，已从本机移除，重新填一个再试"
                } else {
                    errorText = error.message
                }
                needsKeyFix = error.needsKeyFix
            } catch is CancellationError {
                errorText = nil
            } catch {
                errorText = "生成没成功，可以重试，或改用粘贴导入"
            }
            isGenerating = false
        }
    }
}
