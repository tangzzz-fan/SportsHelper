import SwiftUI
import DongKeCore

struct AIGenerateCard: View {
    var onGenerated: (ParsedPlanDraft) -> Void

    @Environment(AISettingsStore.self) private var ai
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.colorScheme) private var colorScheme

    @State private var isGenerating = false
    @State private var errorText: String?
    @State private var needsKeyFix = false
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("用 AI 生成")
                .font(.system(size: 16, weight: .semibold))
            Text(ai.isConfigured
                 ? "按你的档案生成一周计划，生成后照常在下一页校对再保存。"
                 : "先填接口地址与 API Key，才能在这里直接生成；也可以复制提示词去网页版，再把结果粘回来。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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
    }

    @ViewBuilder
    private var action: some View {
        if ai.isConfigured {
            Button(action: generate) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isGenerating ? "生成中…" : "用 AI 生成计划")
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

    private func generate() {
        guard isGenerating == false else { return }
        isGenerating = true
        errorText = nil
        needsKeyFix = false
        let profile = profiles.profile ?? UserProfile()
        Task {
            do {
                let draft = try await AIPlanClient().generatePlan(profile: profile, extraNote: "")
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
