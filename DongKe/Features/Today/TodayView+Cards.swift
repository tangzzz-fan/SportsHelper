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
        guard let occurrence = todayOccurrence else { return true }
        return Calendar.current.isDateInToday(occurrence.date) == false
    }

    var todayIsDone: Bool {
        guard let occurrence = todayOccurrence, isRestToday == false else { return false }
        return HistoryStats.isDone(occurrence, in: store.summaries)
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
        let skipped = daySkip.isSkipped()
        let done = todayIsDone
        let weeklyTarget = plan.meta.weeklyTarget(skipped: daySkip.skippedThisWeek())
        return VStack(alignment: .leading, spacing: 12) {
            Text(resting ? "今天休息" : day.title)
                .font(Typography.detailTitle)

            if skipped {
                Text("今天标记为不练。明天照常，本周目标已减一。")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(A11y.Today.skipToday)
            }

            if done {
                Text("这一节已经练过，本周算过了。再练一次不再重复计。")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(A11y.Today.alreadyDone)
            }

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
                    Text("\(store.completedDaysThisWeek) / \(weeklyTarget)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                ProgressBar(progress: min(1, Double(store.completedDaysThisWeek) / Double(weeklyTarget)))
            }
            .padding(.top, 12)

            Button(action: onStart) {
                Text(buttonTitle(resting: resting, skipped: skipped, done: done))
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

            if done == false {
                if skipped {
                    Button {
                        daySkip.undo()
                    } label: {
                        Text("撤销，今天还是练")
                            .font(Typography.secondary)
                            .foregroundStyle(Theme.accent(for: colorScheme))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .accessibilityIdentifier(A11y.Today.undoSkipToday)
                } else {
                    Button {
                        showSkipConfirm = true
                    } label: {
                        Text("今天不练")
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .accessibilityIdentifier(A11y.Today.skipToday)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func buttonTitle(resting: Bool, skipped: Bool, done: Bool) -> String {
        if done { return "再练一次" }
        if skipped { return "还是练一次" }
        return resting ? "提前练一次" : "开始训练"
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
