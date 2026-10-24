import SwiftUI
import DongKeCore

struct OnboardingView: View {
    var onFinish: (UserProfile) -> Void

    @State var draft = OnboardingDraft()
    @State var step: OnboardingStep
    @Environment(\.colorScheme) var colorScheme

    init(initialStep: OnboardingStep = .basics, onFinish: @escaping (UserProfile) -> Void) {
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        ZStack(alignment: .top) {
            background

            VStack(alignment: .leading, spacing: 0) {
                progressDots
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Text(step.title)
                    .font(Typography.actionTitle)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                Text(step.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                ScrollView {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    private var background: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.8, y: 0.12),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                Text(step == .healthAndReminder ? "完成" : "下一步")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                draft.canAdvance(from: step) ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.18),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .disabled(!draft.canAdvance(from: step))
            .accessibilityIdentifier(A11y.Onboarding.next)

            Button {
                if step == .basics {
                    finish(with: draft.profile)
                } else {
                    back()
                }
            } label: {
                Text(step == .basics ? "跳过，用默认值" : "返回")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11y.Onboarding.skip)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    var goalOptions: [(PlanGoal, String)] {
        PlanGoal.allCases.map { ($0, $0.chineseName) }
    }

    var levelOptions: [(TrainingLevel, String)] {
        TrainingLevel.allCases.map { ($0, $0.chineseName) }
    }

    private func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            finish(with: draft.profile)
        }
    }

    private func back() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func finish(with profile: UserProfile) {
        onFinish(draft.completedProfile(now: Date()))
    }

    func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }

}
