import SwiftUI
import DongKeCore

struct RestSheetView: View {
    @Bindable var session: WorkoutSession
    /// 卡片实际高度。外层要拿它把动作图往上让，否则人物会被卡片从腰上切断。
    var onCardHeightChange: (CGFloat) -> Void = { _ in }

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

    /// 卡片内的垂直节奏。
    ///
    /// 原来混用 4 / 14 / 16 / 32，再靠写死的 `frame(height: 393)` 加 `Spacer` 把空隙塞到中间，
    /// 于是环上下最松、数字上下最紧，整块看起来分成两截。现在只留 8 / 12 / 16 / 20 四档，
    /// 高度由内容决定。
    private enum Metrics {
        static let horizontal: CGFloat = 20
        static let top: CGFloat = 10
        static let kickerTop: CGFloat = 14
        static let timerTop: CGFloat = 2
        static let ringTop: CGFloat = 12
        static let extrasTop: CGFloat = 14
        static let extrasToButtons: CGFloat = 18
        static let buttonTop: CGFloat = 20
        static let bottom: CGFloat = 16
        static let ring: CGFloat = 56
        static let ringWidth: CGFloat = 7
        static let buttonHeight: CGFloat = 50
        static let buttonSpacing: CGFloat = 10
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture { }

                card(bottomInset: proxy.safeAreaInsets.bottom)
            }
        }
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }

    /// 卡片一直铺到屏幕底边（否则 home indicator 那一条会露出灰底，像浮在半空），
    /// 但内容仍然让出安全区。
    private func card(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, Metrics.top)

            Text(session.restKicker)
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .padding(.top, Metrics.kickerTop)

            Text(timeText)
                .font(Typography.timer)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .accessibilityLabel("休息剩余")
                .accessibilityValue(spokenRemaining)
                .padding(.top, Metrics.timerTop)

            ring
                .padding(.top, Metrics.ringTop)

            if showsExtraSetRow {
                extraSetRow
                    .padding(.top, Metrics.extrasTop)
            }

            buttonRow
                .padding(.top, showsExtraSetRow ? Metrics.extrasToButtons : Metrics.buttonTop)
                .padding(.bottom, Metrics.bottom + bottomInset)
        }
        .padding(.horizontal, Metrics.horizontal)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .glassSurface(radius: Theme.Radius.glassSheet)
        .onGeometryChange(
            for: CGFloat.self,
            of: { $0.size.height },
            action: onCardHeightChange
        )
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: Metrics.ringWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.accent(for: colorScheme),
                    style: StrokeStyle(lineWidth: Metrics.ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: Metrics.ring, height: Metrics.ring)
        .animation(.linear(duration: 0.2), value: progress)
    }

    private var showsExtraSetRow: Bool {
        session.canAddExtraSet || session.hasQueuedExtra
    }

    @ViewBuilder
    private var extraSetRow: some View {
        if session.hasQueuedExtra {
            HStack(spacing: 8) {
                Text("已加一组，休息完继续")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(A11y.Workout.extraQueued)
                Spacer(minLength: 8)
                Button("撤销") { session.undoExtraSet() }
                    .font(Typography.meta.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11y.Workout.undoExtraSet)
            }
            .frame(height: 44)
        } else if session.canAddExtraSet {
            // 加组是低频的可选动作，不该和「+15 秒 / 暂停 / 跳过」抢同样的重量。
            // 改成整行可点的文字按钮：位置不变、命中区 44，但视觉降一级。
            Button {
                session.addExtraSet()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("今天再加一组")
                }
                .font(Typography.secondary.weight(.medium))
                .foregroundStyle(Theme.accent(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11y.Workout.addExtraSet)
            .accessibilityLabel("今天再加一组")
        }
    }

    private var isPaused: Bool {
        if case .paused = session.rest { return true }
        return false
    }

    private var buttonRow: some View {
        HStack(spacing: Metrics.buttonSpacing) {
            sheetButton("+15 秒") { session.extendRest() }
            sheetButton(isPaused ? "继续" : "暂停") { session.togglePauseRest() }
            sheetButton("跳过") { session.skipRest() }
                .accessibilityIdentifier(A11y.Workout.skipRest)
        }
    }

    private func sheetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body)
                .frame(maxWidth: .infinity)
                .frame(height: Metrics.buttonHeight)
        }
        .buttonStyle(PressableGlassStyle())
        .glassSurface(radius: Theme.Radius.card)
    }
}
