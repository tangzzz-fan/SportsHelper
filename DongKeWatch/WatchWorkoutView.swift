import SwiftUI
import DongKeCore

struct WatchWorkoutView: View {
    @Bindable var session: WatchWorkoutSession
    let context: WatchContext

    var body: some View {
        if session.isResting {
            WatchRestView(session: session, context: context)
        } else {
            setPage
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
                    session.completeSet(in: context)
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
