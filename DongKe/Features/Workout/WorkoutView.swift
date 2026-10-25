import SwiftUI
import DongKeCore

struct WorkoutView: View {
    @Bindable var session: WorkoutSession
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSkipOptions = false
    @State private var showDowngradeOptions = false
    @State private var bonusReps = 0
    @State private var effort: Int?
    @Bindable private var voiceSettings = VoiceSettingsStore.shared

    private var prescription: ExercisePrescription? { session.currentPrescription }

    private var doseText: String {
        guard let prescription else { return "" }
        let target = prescription.target
        let perSide = target.perSide ? " / 侧" : ""
        return "\(target.doseText)\(perSide) × \(prescription.sets) 组"
    }

    private var figureSize: CGSize {
        typeSize.isAccessibilitySize ? CGSize(width: 132, height: 156) : CGSize(width: 220, height: 260)
    }

    private var cueLines: [String] {
        guard let id = prescription?.catalogId else { return [] }
        guard let entry = ExerciseLibrary.all.first(where: { $0.id == id }) else { return [] }
        return Array(entry.cues.prefix(2))
    }

    private var halfTargetTitle: String {
        prescription?.target.type == .durationSec ? "减一半时间" : "减一半次数"
    }

    private var setCounterText: Text {
        Text("第 \(session.currentSetIndex) 组")
            .font(Typography.meta.weight(.semibold)) +
        Text(" / 共 \(session.currentSetTotal) 组")
            .font(Typography.meta)
            .foregroundColor(.secondary)
    }

    var body: some View {
        if session.showsSummary {
            WorkoutSummaryView(title: session.sessionTitle, recap: session.recap, onDone: onClose)
        } else {
            workoutBody
        }
    }

    private var workoutBody: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if let prescription {
                ExerciseFigureView(catalogId: prescription.catalogId,
                                       figureSize: CGSize(width: 430, height: 500),
                                       showsHalo: false)
                    .opacity(0.06)
                    .offset(x: 140, y: -170)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                navBar

                GeometryReader { proxy in
                    ScrollView {
                        Group {
                            if let prescription {
                                VStack(spacing: typeSize.isAccessibilitySize ? 10 : 18) {
                                    ExerciseFigureView(catalogId: prescription.catalogId, figureSize: figureSize)

                                    VStack(spacing: 2) {
                                        Text(prescription.name)
                                            .font(Typography.buttonLabel)
                                        Text(doseText)
                                            .font(Typography.body)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        if cueLines.isEmpty == false {
                                            VStack(spacing: 3) {
                                                ForEach(cueLines, id: \.self) { cue in
                                                    Text(cue)
                                                        .font(Typography.meta)
                                                        .foregroundStyle(.tertiary)
                                                        .multilineTextAlignment(.center)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                            }
                                            .padding(.top, 8)
                                            .accessibilityIdentifier(A11y.Workout.cues)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: proxy.size.height, alignment: .center)
                            } else {
                                finishedPlaceholder
                                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                if !session.isResting {
                    controlDock
                }
            }

            if session.isResting {
                RestSheetView(session: session)
                    .transition(.opacity)
            }
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            session.refresh()
        }
        .onChange(of: session.restFinishedToken) { _, _ in
            Haptics.restFinished()
        }
        .onChange(of: session.setTimerReachedToken) { _, token in
            guard token > 0 else { return }
            Haptics.setTimeUp()
        }
        .onChange(of: session.stepIndex) { _, _ in
            bonusReps = 0
            effort = nil
        }
        .onAppear(perform: startVoiceIfNeeded)
        .onDisappear(perform: stopVoice)
        .onChange(of: scenePhase) { _, _ in
            VoiceService.shared.refreshPolicy()
        }
        .onChange(of: voiceSettings.isEnabled) { _, enabled in
            if enabled {
                startVoiceIfNeeded()
            } else {
                VoiceService.shared.refreshPolicy()
            }
        }
    }

    private func startVoiceIfNeeded() {
        guard session.showsSummary == false, VoiceService.isEnabledByUser else { return }
        if session.voice != nil {
            VoiceService.shared.refreshPolicy()
            return
        }
        let coordinator = VoiceService.shared.activeCoordinator()
        let voice = WorkoutVoiceSession(
            plan: session.plan,
            dayIndex: session.dayIndex,
            coordinator: coordinator
        )
        session.voice = voice
        voice.start()
        voice.stepChanged(to: session.stepIndex)
    }

    private func stopVoice() {
        session.voice?.stop()
        session.voice = nil
        VoiceService.shared.shutdown()
    }

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: Icons.close)
                    .font(Typography.buttonLabel)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .fixedSize()
            }
            .foregroundStyle(Theme.accent(for: colorScheme))
            .accessibilityIdentifier(A11y.Workout.close)

            Spacer(minLength: 8)

            Text(session.sessionTitle)
                .font(Typography.buttonLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .layoutPriority(0)

            Spacer(minLength: 8)

            Button {
                session.endWorkout()
            } label: {
                Text("结束")
                    .font(Typography.buttonLabel)
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(minWidth: 52, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityIdentifier(A11y.Workout.end)
        }
        .padding(.horizontal, 8)
        .glassSurface(radius: Theme.Radius.glassIsland)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var finishedPlaceholder: some View {
        VStack(spacing: 12) {
            Text("本次训练完成")
                .font(.title3.weight(.semibold))
            Text("已完成 \(session.completedSets) / \(session.plannedSets) 组")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let done = weeklyDone {
                Text(done)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(A11y.Workout.weeklyProgress)
            }
        }
    }

    private var weeklyDone: String? {
        guard let store = session.store else { return nil }
        let target = session.plan.meta.weeklyTarget(skipped: DaySkipStore.shared.skippedThisWeek())
        return "本周 \(min(store.completedDaysThisWeek, target)) / \(target)"
    }

    private var completeButtonTitle: String {
        guard bonusReps > 0, let target = session.currentTarget else { return "完成本组" }
        return "完成 \(target.value + bonusReps) 次"
    }

    private var bonusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("比目标多做几个")
                .font(Typography.capsLabel)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0...3, id: \.self) { value in
                    chip(value == 0 ? "刚好" : "+\(value)", on: bonusReps == value) {
                        bonusReps = value
                    }
                    .accessibilityIdentifier(A11y.Workout.bonusReps(value))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var effortRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("这组还剩几次力气？不选也行")
                .font(Typography.capsLabel)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { level in
                    chip(effortLabel(level), on: effort == level) {
                        effort = effort == level ? nil : level
                    }
                    .accessibilityIdentifier(A11y.Workout.effort(level))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func effortLabel(_ level: Int) -> String {
        switch level {
        case 1: "很轻松"
        case 2: "还能 3 次"
        case 3: "还能 2 次"
        case 4: "还能 1 次"
        default: "已经力竭"
        }
    }

    private func chip(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Typography.capsLabel.weight(.medium))
                .foregroundStyle(on ? Theme.callToActionInk(for: colorScheme) : Color.primary.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 9)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    on ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.07),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressableGlassStyle())
    }

    private var controlDock: some View {
        VStack(spacing: 8) {
            setCounterText
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)

            ProgressBar(progress: session.progress)

            if session.showsSetCountdown {
                SetCountdownBadge(remainingSeconds: session.setRemainingDisplay)
                    .padding(.top, 6)
            }

            if session.acceptsBonusReps {
                bonusRow
                    .padding(.top, 12)
            }

            if session.isLastSetOfItem {
                effortRow
                    .padding(.top, 10)
            }

            Button {
                let extra = bonusReps
                let rated = effort
                bonusReps = 0
                effort = nil
                session.completeSet(bonus: extra, rpe: rated)
            } label: {
                Text(completeButtonTitle)
                    .font(Typography.buttonLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                Theme.accent(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier(A11y.Workout.completeSet)
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
            .padding(.top, 16)

            Button {
                showDowngradeOptions = true
            } label: {
                Text("这组做不动")
                    .font(Typography.body)
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .accessibilityIdentifier(A11y.Workout.downgrade)

            Button {
                showSkipOptions = true
            } label: {
                Text("跳过本组")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .accessibilityIdentifier(A11y.Workout.skipSet)
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.glassCard)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .confirmationDialog("为什么跳过这组？", isPresented: $showSkipOptions, titleVisibility: .visible) {
            Button("没时间") { session.skipSet(reason: .noTime) }
                .accessibilityIdentifier(A11y.Workout.skipReasonNoTime)
            Button("太累了") { session.skipSet(reason: .tooHard) }
            Button("身体不适") { session.skipSet(reason: .pain) }
            Button("缺器械") { session.skipSet(reason: .noEquipment) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("这组做不动", isPresented: $showDowngradeOptions, titleVisibility: .visible) {
            Button(halfTargetTitle) { session.downgradeSet() }
                .accessibilityIdentifier(A11y.Workout.downgradeHalf)
            Button("取消", role: .cancel) {}
        } message: {
            Text("只改这一组，后面照原计划；这一组记作降阶完成。")
        }
    }
}
