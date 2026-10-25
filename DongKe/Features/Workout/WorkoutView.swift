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
    @State private var voiceStopTask: Task<Void, Never>?
    /// 休息面板的实际高度。休息时动作图要在面板以上居中，否则会被从腰上切断。
    @State private var restSheetHeight: CGFloat = 0
    @Bindable private var voiceSettings = VoiceSettingsStore.shared

    private var prescription: ExercisePrescription? { session.currentPrescription }

    private var restingInset: CGFloat {
        session.isResting ? restSheetHeight : 0
    }

    private var doseText: String {
        guard let prescription else { return "" }
        let target = prescription.target
        let perSide = target.perSide ? " / 侧" : ""
        return "\(target.doseText)\(perSide) × \(prescription.sets) 组"
    }

    private var figureSize: CGSize {
        // 休息时面板吃掉将近半屏，图要缩一档，否则注解那两行会被面板压住。
        if session.isResting {
            return typeSize.isAccessibilitySize ? CGSize(width: 118, height: 138) : CGSize(width: 186, height: 220)
        }
        return typeSize.isAccessibilitySize ? CGSize(width: 132, height: 156) : CGSize(width: 220, height: 260)
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
            WorkoutSummaryView(title: session.sessionTitle, recap: session.recap, onDone: close)
        } else {
            workoutBody
        }
    }

    private var workoutBody: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                GeometryReader { proxy in
                    ScrollView {
                        Group {
                            if let prescription {
                                VStack(spacing: typeSize.isAccessibilitySize ? 10 : 18) {
                                    ExerciseFigureView(
                                        catalogId: prescription.catalogId,
                                        figureSize: figureSize,
                                        autoPlays: true
                                    )

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
                                                        .font(Typography.secondary.weight(.medium))
                                                        .foregroundStyle(.secondary)
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
                                .frame(minHeight: max(0, proxy.size.height - restingInset), alignment: .center)
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
                RestSheetView(session: session) { height in
                    // 动画期间会报几次不同的高度，差 1pt 以内不写回，避免自激。
                    if abs(height - restSheetHeight) > 1 {
                        restSheetHeight = height
                    }
                }
                .transition(.opacity)
            }
        }
        .background {
            // 装饰用的放大动作图：只画，不参与布局。
            // 它有 430pt 宽，直接放进 ZStack 会把整页撑得比屏幕宽——
            // 后果是休息面板的 20pt 边距只剩 6pt、顶部 X 贴到屏幕边缘。
            // 裁剪只做在这一层：给整个 ZStack 加 .clipped() 会连带把
            // 休息面板裁进安全区，面板就永远贴不到屏幕底边。
            GeometryReader { _ in
                if let prescription {
                    ExerciseFigureView(
                        catalogId: prescription.catalogId,
                        figureSize: CGSize(width: 430, height: 500),
                        showsHalo: false
                    )
                    .opacity(0.06)
                    .offset(x: 140, y: -170)
                    .allowsHitTesting(false)
                }
            }
            .clipped()
        }
        .animation(.easeOut(duration: 0.22), value: restSheetHeight)
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
        .onDisappear(perform: scheduleVoiceTeardown)
        .onChange(of: scenePhase) { _, phase in
            VoiceService.shared.refreshPolicy(isForeground: phase != .background)
        }
        .onChange(of: voiceSettings.level) { _, level in
            VoiceService.shared.refreshPolicy()
            session.voice?.level = level
            if level.isEnabled, session.showsSummary == false {
                startVoiceIfNeeded()
            }
        }
    }

    private func startVoiceIfNeeded() {
        voiceStopTask?.cancel()
        voiceStopTask = nil
        guard session.showsSummary == false, VoiceService.isEnabledByUser else {
            VoiceService.shared.refreshPolicy()
            return
        }
        // 会话按 sessionId 缓存：视图重建几次都拿回同一个实例，开场只念一次。
        let voice = VoiceService.shared.voice(
            for: session.id,
            plan: session.plan,
            dayIndex: session.dayIndex,
            steps: session.script
        )
        session.voice = voice
        voice.level = VoiceService.levelByUser
        VoiceService.shared.refreshPolicy(isForeground: scenePhase != .background)
        voice.start(atStep: session.stepIndex)
        voice.stepChanged(to: session.stepIndex)
    }

    /// 视图消失不等于这节课结束。
    ///
    /// fullScreenCover 的转场会成对触发 onDisappear / onAppear，以前在 onDisappear 里
    /// 直接拆会话，于是整节课的音频会话被释放又重建，开场被重念一遍。这里延后 0.8 秒：
    /// 真的关掉了才拆，转场抖动会被下一次 onAppear 取消。
    private func scheduleVoiceTeardown() {
        voiceStopTask?.cancel()
        voiceStopTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            guard Task.isCancelled == false else { return }
            finishVoice()
        }
    }

    private func finishVoice() {
        voiceStopTask?.cancel()
        voiceStopTask = nil
        VoiceService.shared.endVoice(sessionId: session.id)
        session.voice = nil
        VoiceService.shared.shutdown()
    }

    private func close() {
        finishVoice()
        onClose()
    }

    /// 顶部栏走系统的内联样式：左取消、中间标题、右结束，不加玻璃胶囊。
    /// 原来三样东西装在一个 40pt 圆角的胶囊里、左右还各留 8pt，看起来像浮在页面上的工具条。
    private var navBar: some View {
        ZStack {
            Text(session.sessionTitle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 76)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 0) {
                Button(action: close) {
                    Image(systemName: Icons.close)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Workout.close)
                .accessibilityLabel("关闭")

                Spacer(minLength: 0)

                Button {
                    session.endWorkout()
                } label: {
                    Text("结束")
                        .font(Typography.buttonLabel)
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Workout.end)
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 4)
    }

    private var finishedPlaceholder: some View {
        VStack(spacing: 12) {
            Text("本次训练完成")
                .font(.title3.weight(.semibold))
            Text("已完成 \(session.completedSets) / \(session.plannedSets) 组")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if session.extraSetsCompleted > 0 {
                Text("另有 \(session.extraSetsCompleted) 组额外加练")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
            Text(effortTitle)
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

    private var isHoldTarget: Bool {
        session.currentTarget?.type == .durationSec
    }

    private var effortTitle: String {
        isHoldTarget ? "这组还能撑几秒？不选也行" : "这组还剩几次力气？不选也行"
    }

    private func effortLabel(_ level: Int) -> String {
        if isHoldTarget {
            switch level {
            case 1: return "很轻松"
            case 2: return "还能 10 秒"
            case 3: return "还能 5 秒"
            case 4: return "还能 2 秒"
            default: return "已经力竭"
            }
        }
        switch level {
        case 1: return "很轻松"
        case 2: return "还能 3 次"
        case 3: return "还能 2 次"
        case 4: return "还能 1 次"
        default: return "已经力竭"
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
