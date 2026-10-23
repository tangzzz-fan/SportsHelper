import SwiftUI
import DongKeCore

extension TodayView {
    var backgroundLayer: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.85, y: 0.32),
                startRadius: 0,
                endRadius: 320
            )

            if let catalogId = today?.blocks.first?.items.first?.catalogId {
                ExerciseFigureView(catalogId: catalogId,
                                   figureSize: CGSize(width: 320, height: 372),
                                   showsHalo: false)
                    .opacity(0.08)
                    .rotationEffect(.degrees(-4))
                    .offset(x: 78, y: 96)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    var isRestToday: Bool {
        let weekday = SampleData.weekday(for: Date())
        guard let day = plan.days.first(where: { $0.weekday == weekday }) else { return true }
        return day.isRestDay
    }

    func resumeCard(_ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("上次训练没做完")
                .font(Typography.cardTitle)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(action: onResume) {
                Text("继续训练")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.accent(for: colorScheme).opacity(0.35), lineWidth: 1)
            )
            .accessibilityIdentifier(A11y.Today.resume)
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    func sessionCard(_ day: PlanDay) -> some View {
        let items = day.blocks.flatMap(\.items)
        let resting = isRestToday
        return VStack(alignment: .leading, spacing: 12) {
            Text(resting ? "今天休息" : day.title)
                .font(Typography.detailTitle)

            Text(resting
                 ? "下次训练 \(day.weekday.chineseName) \(timeText(day)) · \(items.count) 个动作"
                 : "\(items.count) 个动作 · 约 \(day.estimatedMinutes) 分钟 · \(timeText(day))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Text("本周")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.completedThisWeek) / \(plan.meta.daysPerWeek)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                ProgressBar(progress: min(1, Double(store.completedThisWeek) / Double(max(1, plan.meta.daysPerWeek))))
            }
            .padding(.top, 12)

            Button(action: onStart) {
                Text(isRestToday ? "提前练一次" : "开始训练")
                    .font(.headline)
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
            .accessibilityIdentifier(A11y.Today.start)
            .padding(.top, 12)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    var nextTrainingDay: PlanDay? {
        let training = plan.days.filter { !$0.isRestDay }
        guard !training.isEmpty else { return nil }
        let today = SampleData.weekday(for: Date()).rawValue
        return training.first(where: { $0.weekday.rawValue > today }) ?? training.first
    }

    func timeText(_ day: PlanDay) -> String {
        guard let time = day.scheduledTime else { return "—" }
        return String(format: "%02d:%02d", time.hour, time.minute)
    }
}
