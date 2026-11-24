import SwiftUI
import DongKeCore

struct WatchWorkoutView: View {
    @Bindable var session: WatchWorkoutSession
    let context: WatchContext
    var onCompleteSet: () -> Void = {}

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

            if let display = setDisplay {
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
                    onCompleteSet()
                }
                .disabled(true)
                .padding(.top, 4)

                Text("本组在 iPhone 上记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        guard let display = setDisplay else { return "训练已结束" }
        return "\(display.name)，第 \(display.setIndex) 组，共 \(display.setCount) 组，目标 \(display.targetText)"
    }

    private var setDisplay: WatchSetDisplay? {
        guard let steps = context.checkpoint.steps,
              steps.indices.contains(context.checkpoint.stepIndex)
        else {
            return nil
        }
        for index in context.checkpoint.stepIndex..<steps.count {
            if case let .set(prescriptionId, setIndex, target, _) = steps[index],
               let exercise = context.exercise(for: prescriptionId) {
                return WatchSetDisplay(
                    name: exercise.name,
                    setIndex: setIndex,
                    setCount: exercise.setCount,
                    targetText: target.perSide ? "每侧 \(target.doseText)" : target.doseText
                )
            }
        }
        return nil
    }
}

private struct WatchSetDisplay {
    var name: String
    var setIndex: Int
    var setCount: Int
    var targetText: String
}
