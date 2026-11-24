import SwiftUI
import DongKeCore

/// 断点续练的岔路口，只在 `ResumePrompt.shouldAsk` 为真时出现。
///
/// 这里刻意没有「重新开始」：`WatchWorkoutSession.resolvedStepIndex` 取
/// `max(localStepIndex, checkpoint.stepIndex)`，本地归零会被下一次上下文更新
/// 立刻拉回原组。要支持它得先有「放弃会话」的协议（iPhone 把旧会话标 abandoned
/// 再开新 sessionId），见 W2.2 票里拆出去的那一项。
struct WatchResumeChoiceView: View {
    let set: WatchSetSummary?
    let onResume: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("上次没练完")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(headline)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            Button(action: onResume) {
                Text("继续练")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.accent)

            Button(action: onDecline) {
                Text("今天不练了")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private var headline: String {
        guard let set else { return "有一段没练完" }
        return "第 \(set.setIndex) 组"
    }

    private var detail: String {
        guard let set else { return "接着上次继续" }
        return "共 \(set.setCount) 组 · \(set.name)"
    }
}
