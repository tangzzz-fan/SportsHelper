import SwiftUI
import DongKeCore

struct PlanOriginNotice: View {
    let source: PlanSource

    var body: some View {
        if let text {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: Icons.mistake)
                    .font(Typography.micro)
                Text(text)
                    .font(Typography.meta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .accessibilityIdentifier(A11y.Plan.originNotice)
        }
    }

    private var text: String? {
        switch source {
        case .ai:
            "这份计划由 AI 整理。AI 可能写错动作名、组数或时长，也可能漏掉你的旧伤——保存前逐条看一眼，别照单全收。"
        case .pasteJSON, .pasteText:
            "这份计划照搬了你粘贴的内容，原文有错它就有错。保存前逐条看一眼。"
        case .generated, .manual:
            nil
        }
    }
}

struct PlanOriginBadge: View {
    let source: PlanSource

    var body: some View {
        if source.isMachineWritten {
            Text(source.chineseName)
                .font(Typography.capsLabel)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.07), in: Capsule())
                .accessibilityIdentifier(A11y.Plan.originBadge)
        }
    }
}
