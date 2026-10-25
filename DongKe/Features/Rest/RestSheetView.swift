import SwiftUI
import DongKeCore

struct RestSheetView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.colorScheme) private var colorScheme
    @State private var now = Date()

    private var remaining: Int {
        max(0, Int(session.remainingRest(now: now).rounded(.up)))
    }

    private var total: Int {
        max(1, session.totalRestSeconds())
    }

    private var progress: Double {
        min(1, max(0, Double(remaining) / Double(total)))
    }

    private var timeText: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private var spokenRemaining: String {
        let seconds = remaining / 10 * 10
        let minutes = seconds / 60
        let rest = seconds % 60
        if minutes > 0, rest > 0 { return "\(minutes) 分 \(rest) 秒" }
        if minutes > 0 { return "\(minutes) 分" }
        return "\(rest) 秒"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.primary.opacity(0.30))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Text(session.restKicker)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)

                Text(timeText)
                    .font(Typography.timer)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .accessibilityLabel("休息剩余")
                    .accessibilityValue(spokenRemaining)
                    .padding(.top, 4)

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Theme.accent(for: colorScheme),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 64, height: 64)
                .padding(.top, 16)

                extraSetRow
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    sheetButton("+15 秒") { session.extendRest() }
                    sheetButton(isPaused ? "继续" : "暂停") { session.togglePauseRest() }
                    sheetButton("跳过") { session.skipRest() }
                        .accessibilityIdentifier(A11y.Workout.skipRest)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .frame(height: showsExtraSetRow ? 393 : 331)
            .frame(maxWidth: .infinity)
            .glassSurface(radius: Theme.Radius.glassSheet)
            .padding(.horizontal, 0)
        }
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }

    private var showsExtraSetRow: Bool {
        session.canAddExtraSet || session.hasQueuedExtra
    }

    @ViewBuilder
    private var extraSetRow: some View {
        if session.hasQueuedExtra {
            HStack(spacing: 8) {
                Text("已加一组，休息完继续")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(A11y.Workout.extraQueued)
                Spacer(minLength: 8)
                Button("撤销") { session.undoExtraSet() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11y.Workout.undoExtraSet)
            }
        } else if session.canAddExtraSet {
            Button { session.addExtraSet() } label: {
                Text("今天再加一组")
                    .font(Typography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PressableGlassStyle())
            .glassSurface(radius: 20)
            .accessibilityIdentifier(A11y.Workout.addExtraSet)
        }
    }

    private var isPaused: Bool {
        if case .paused = session.rest { return true }
        return false
    }

    private func sheetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(PressableGlassStyle())
        .glassSurface(radius: 20)
    }
}
