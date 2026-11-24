import SwiftUI
import DongKeCore

/// 断点续练的岔路口，只在 `ResumePrompt.shouldAsk` 为真时出现。
///
/// 「重新开始」不是一个本地操作：`WatchWorkoutSession.resolvedStepIndex` 取
/// `max(localStepIndex, checkpoint.stepIndex)`，本地把进度归零会被下一次上下文
/// 更新立刻拉回原组。所以它只能请 iPhone 丢掉旧会话、开一个新的，手表拿新
/// `sessionId` 才能真的从头开始——这段时间显示等待态，期间不能记组。
struct WatchResumeChoiceView: View {
    let set: WatchSetSummary?
    var phase: RestartWaitState = .idle
    let onResume: () -> Void
    let onRestart: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("上次没练完")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(headline)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
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

            if case .waiting = phase {
                waitingBody
            } else {
                actions
            }
        }
        .padding(.horizontal, 4)
    }

    private var waitingBody: some View {
        VStack(spacing: 6) {
            ProgressView()
            Text("正在联系 iPhone…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在联系 iPhone，请稍候")
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button(action: onResume) {
                Text("继续练")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.accent)

            Button(action: onRestart) {
                Text("重新开始")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if case .failed = phase {
                Text("iPhone 没响应，稍后再试")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDecline) {
                Text("今天不练了")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
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
