import SwiftUI
import DongKeCore

struct WatchWorkoutView: View {
    @Bindable var session: WatchWorkoutSession
    let context: WatchContext
    let planRevision: Int?

    private var validation: CheckpointValidation {
        CheckpointValidator.validate(
            context.checkpoint,
            currentPlanRevision: planRevision ?? context.checkpoint.revision,
            now: Date()
        )
    }

    var body: some View {
        switch validation {
        case .resumable:
            if session.isResting {
                WatchRestView(session: session, context: context)
            } else {
                setPage
            }
        case .notInProgress:
            WatchMessageView(title: "训练已结束", detail: "请在 iPhone 上查看总结")
        case .planChanged:
            WatchMessageView(title: "计划已更新", detail: "请回到 iPhone 完成或重新开始本次训练")
        case .expired:
            WatchMessageView(title: "本次训练已过期", detail: "请在 iPhone 上重新开始")
        }
    }

    private var setPage: some View {
        VStack(spacing: 4) {
            Text(context.dayTitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let display = session.currentSet(in: context) {
                Text(display.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text("第 \(display.setIndex) 组，共 \(display.setCount) 组")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(display.targetText)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Button("完成本组") {
                    session.completeSet(in: context, planRevision: planRevision)
                }
                .padding(.top, 4)

                if let status = session.logStatusText {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("训练已结束")
                    .font(.headline)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let display = session.currentSet(in: context) else { return "训练已结束" }
        var text = "\(display.name)，第 \(display.setIndex) 组，共 \(display.setCount) 组，目标 \(display.targetText)"
        if let status = session.logStatusText {
            text += "，\(status)"
        }
        return text
    }
}

private struct WatchMessageView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}
