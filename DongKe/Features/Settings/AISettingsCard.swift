import SwiftUI
import DongKeCore

struct AISettingsCard: View {
    @Environment(AISettingsStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var baseURL = ""
    @State private var model = ""
    @State private var keyDraft = ""
    @State private var feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            input(
                title: "接口地址",
                prompt: "https://api.openai.com/v1",
                text: $baseURL,
                isSecure: false,
                usesURLKeyboard: true
            )

            input(
                title: "模型",
                prompt: AIConfiguration.defaultModel,
                text: $model,
                isSecure: false
            )

            input(
                title: "API Key",
                prompt: store.hasKey ? "已保存，输入新的可覆盖" : "sk-…",
                text: $keyDraft,
                isSecure: true
            )

            actionRow

            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Key 存在本机钥匙串，不上传。只有你主动点「用 AI 生成」时才会把档案与要求发给你填的这个服务；其余功能离线可用。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 直连")
                    .font(.system(size: 16, weight: .medium))
                Text("OpenAI 兼容接口，自己填地址与 Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: store.isConfigured ? "checkmark.circle" : "circle.dashed")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(store.isConfigured ? Theme.accent(for: colorScheme) : Color.secondary)
        }
    }

    private func input(
        title: String,
        prompt: String,
        text: Binding<String>,
        isSecure: Bool,
        usesURLKeyboard: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Group {
                if isSecure {
                    SecureField(prompt, text: text)
                } else {
                    TextField(prompt, text: text)
                }
            }
            .font(.system(size: 15, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(usesURLKeyboard ? .URL : .default)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(action: save) {
                Text("保存")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                Theme.accent(for: colorScheme),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )

            if store.hasKey {
                Button {
                    store.clearKey()
                    keyDraft = ""
                    feedback = "已清除 API Key"
                } label: {
                    Text("清除 Key")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(PressableGlassStyle())
                .foregroundStyle(Theme.accent(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.accent(for: colorScheme).opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    private func load() {
        baseURL = store.baseURL
        model = store.model
        keyDraft = ""
    }

    private func save() {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false, case .failure = AIEndpoint.completionsURL(baseURL: trimmed) {
            feedback = AIClientError.invalidBaseURL.message
            return
        }

        store.baseURL = trimmed
        store.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            do {
                try store.saveKey(keyDraft)
            } catch {
                feedback = "Key 没能存进钥匙串，稍后再试"
                return
            }
        }
        keyDraft = ""
        feedback = store.isConfigured ? "已保存，可以去导入页生成计划" : "已保存地址与模型，还需要填 API Key"
    }
}
