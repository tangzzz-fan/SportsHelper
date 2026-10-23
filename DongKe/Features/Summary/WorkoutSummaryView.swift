import SwiftUI
import DongKeCore

struct WorkoutSummaryView: View {
    let title: String
    let recap: SessionRecap
    var onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var ringDiameter: CGFloat {
        typeSize.isAccessibilitySize ? 220 : 156
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.5, y: 0.12),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(spacing: 6) {
                            Text("训练完成")
                                .font(Typography.actionTitle)
                                .accessibilityIdentifier(A11y.Workout.summaryTitle)
                            Text("\(title) · \(recap.durationText)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        ring
                            .padding(.top, typeSize.isAccessibilitySize ? 16 : 28)

                        statCard
                            .padding(.horizontal, 16)
                            .padding(.top, typeSize.isAccessibilitySize ? 16 : 28)

                        Text("降阶的组计入完成率；未做与跳过的组不计。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: contentMinHeight(proxy.size.height))
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .bottom) {
                    doneButton
                }
            }
        }
    }

    private func contentMinHeight(_ available: CGFloat) -> CGFloat {
        typeSize.isAccessibilitySize ? 0 : max(0, available - 96)
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("完成")
                .font(Typography.buttonLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(PressableGlassStyle())
        .foregroundStyle(Theme.callToActionInk(for: colorScheme))
        .background(
            Theme.accent(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.52), .white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .accessibilityIdentifier(A11y.Summary.done)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.001, recap.completionRate))
                .stroke(
                    Theme.accent(for: colorScheme),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(recap.percentText(recap.completionRate))
                    .font(Typography.bigNumber)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier(A11y.Summary.completion)
                Text("\(recap.completedSets) / \(recap.plannedSets) 组")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
    }

    private var statCard: some View {
        HStack(spacing: 0) {
            stat("完成", recap.percentText(recap.completionRate), detail: "\(recap.completedSets) 组")
            divider
            stat("降阶", recap.percentText(recap.downgradeRate), detail: "\(recap.downgradedSets) 组")
            divider
            stat("跳过", recap.percentText(recap.skipRate), detail: "\(recap.skippedSets) 组")
        }
        .padding(.vertical, 18)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 36)
    }

    private func stat(_ label: String, _ value: String, detail: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typography.detailTitle)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
