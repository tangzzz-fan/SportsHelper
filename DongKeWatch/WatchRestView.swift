import SwiftUI
import DongKeCore

struct WatchRestView: View {
    @Bindable var session: WatchWorkoutSession
    let context: WatchContext

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var timeText: String {
        let remaining = max(0, session.remainingSeconds)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var spokenRemaining: String {
        let seconds = max(0, session.remainingSeconds) / 10 * 10
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes > 0, rest > 0 { return "\(minutes) 分 \(rest) 秒" }
        if minutes > 0 { return "\(minutes) 分" }
        return "\(rest) 秒"
    }

    private var setSummary: (name: String, setIndex: Int, setCount: Int)? {
        guard let steps = context.checkpoint.steps,
              steps.indices.contains(context.checkpoint.stepIndex)
        else {
            return nil
        }
        for index in context.checkpoint.stepIndex..<steps.count {
            if case let .set(prescriptionId, setIndex, _, _) = steps[index],
               let exercise = context.exercise(for: prescriptionId) {
                return (exercise.name, setIndex, exercise.setCount)
            }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 4) {
            if let summary = setSummary {
                Text("\(summary.name) · 第 \(summary.setIndex) 组，共 \(summary.setCount) 组")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(timeText)
                .font(.system(size: 88, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel("休息剩余")
                .accessibilityValue(spokenRemaining)

            HStack(spacing: 8) {
                Button("+15 秒") {
                    session.extend(by: 15)
                }
                Button("完成本组") {
                    session.finishRest()
                }
            }
            .font(.footnote)
        }
        .padding(.horizontal, 4)
        .onChange(of: spokenRemaining) { _, value in
            guard voiceOverEnabled, session.isResting else { return }
            AccessibilityNotification.Announcement("休息剩余 \(value)").post()
        }
    }
}
