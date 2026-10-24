import SwiftUI
import DongKeCore

struct SetCountdownBadge: View {
    let remainingSeconds: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if remainingSeconds > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("还剩")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                    Text("\(remainingSeconds)")
                        .font(Typography.bigNumber)
                    Text("秒")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("时间到")
                    .font(Typography.detailTitle)
                    .foregroundStyle(Theme.accent(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11y.Workout.setCountdown)
    }
}
