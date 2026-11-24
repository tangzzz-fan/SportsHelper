import SwiftUI
import DongKeCore

struct WorkoutView: View {
    @Bindable var session: WorkoutSession
    var onClose: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SetLogStore.self) private var setLogs
    @Environment(ProfileStore.self) private var profiles
    @State private var showSkipOptions = false
    @State private var showDowngradeOptions = false
    @State var bonusReps = 0
    @State var effort: Int?
    @State private var voiceStopTask: Task<Void, Never>?
    /// 休息面板的实际高度。休息时动作图要在面板以上居中，否则会被从腰上切断。
    @State private var restSheetHeight: CGFloat = 0
    /// 「上次 10 · 最好 12」。进入本组时算一次，训练中途不跟着变。
    @State private var recordLine: String?
    @State private var showLoadSheet = false
    @State private var showReceipt = false
    @State private var showRackSheet = false
    @Bindable private var rackStore = LoadRackStore.shared
    @State private var showSwapSheet: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["DK_PREVIEW"] == "swap"
        #else
        return false
        #endif
    }()
    @Bindable private var voiceSettings = VoiceSettingsStore.shared

    private var prescription: ExercisePrescription? { session.currentPrescription }

    private var restingInset: CGFloat {
        session.isResting ? restSheetHeight : 0
    }

    private var doseText: String {
        prescription?.workoutDoseLine(load: session.currentLoad) ?? ""
    }

    /// 结束页打开回执时才算一次，不在每次 body 刷新里扫日志。
    private var receiptText: String {
        TrainingReceiptBuilder.build(
            logs: setLogs.recentLogs(limit: 600),
            plan: session.plan
        ).text
    }

    private var figureSize: CGSize {
        // 休息时面板吃掉将近半屏，图要缩一档，否则注解那两行会被面板压住。
        if session.isResting {
            return typeSize.isAccessibilitySize ? CGSize(width: 118, height: 138) : CGSize(width: 186, height: 220)
        }
        return typeSize.isAccessibilitySize ? CGSize(width: 132, height: 156) : CGSize(width: 220, height: 260)
    }

    /// 全部可用动作里，这次能换的那几个。空的时候入口不出现。
    private var swapOptions: [ExerciseEntry] {
        session.swapCandidates(available: profiles.profile?.equipment ?? [.bodyweight])
    }

    private var cueLines: [String] {
        guard let id = prescription?.catalogId else { return [] }
        guard let entry = ExerciseLibrary.all.first(where: { $0.id == id }) else { return [] }
        return Array(entry.cues.prefix(2))
    }

    private var halfTargetTitle: String {
        prescription?.target.type == .durationSec ? "减一半时间" : "减一半次数"
    }

    /// 第一次遇到负重动作时问一次。问过之后不再自动弹，设置页能改。
    private func askRackIfNeeded() {
        guard rackStore.hasAnswered == false, session.currentLoad != nil else { return }
        showRackSheet = true
    }

    private func refreshRecordLine() {
        guard let prescription else {
            recordLine = nil
            return
        }
        let type = prescription.target.type
        guard type != .distanceM else {
            recordLine = nil
            return
        }
        let catalogId = prescription.catalogId
        let logs = setLogs.logs(forCatalogIds: [catalogId], before: session.startedAt)
        let record = PersonalRecords.record(
            for: catalogId,
            unit: type,
            load: session.currentLoad,
            isUsingPrescribedLoad: session.isUsingPrescribedLoad,
            in: PersonalRecords.build(logs: logs)
        )
        recordLine = record?.lineText(unit: type, loadText: session.currentLoad?.shortText)
    }

    /// 重量也是这条对照的一部分：改了重量，「上次」要跟着换成那个重量下的。
    private var recordLineTaskKey: String {
        let id = prescription?.catalogId ?? ""
        return "\(id)#\(session.currentLoad?.recordKey ?? "none")"
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
            WorkoutSummaryView(
                title: session.sessionTitle,
                recap: session.recap,
                narrative: session.narrative,
                onCopyReceipt: { showReceipt = true },
                onDone: close
            )
            .sheet(isPresented: $showReceipt) {
                ReceiptSheet(text: receiptText)
            }
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
                                        Button {
                                            showLoadSheet = true
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(doseText)
                                                if session.currentLoad != nil {
                                                    Image(systemName: "chevron.up.chevron.down")
                                                        .font(.system(size: 10, weight: .semibold))
                                                }
                                            }
                                            .font(Typography.body)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(session.currentLoad == nil)
                                        .accessibilityIdentifier(A11y.Workout.loadAdjust)
                                        if let recordLine {
                                            Text(recordLine)
                                                .font(Typography.secondary)
                                                .foregroundStyle(.tertiary)
                                                .monospacedDigit()
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
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
                                .task(id: recordLineTaskKey) { refreshRecordLine() }
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
        .onAppear(perform: askRackIfNeeded)
        .onAppear { session.saveCheckpoint() }
        .sheet(isPresented: $showRackSheet) {
            LoadRackSheet { rackStore.save($0) }
        }
        .sheet(isPresented: $showLoadSheet) {
            LoadAdjustSheet(session: session)
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapExerciseSheet(
                currentName: prescription?.name ?? "",
                candidates: swapOptions
            ) { entry in
                session.swapCurrent(with: entry)
                bonusReps = 0
                effort = nil
            }
        }
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

            HStack(spacing: 0) {
                if swapOptions.isEmpty == false {
                    Button {
                        showSwapSheet = true
                    } label: {
                        Text("换个动作")
                            .font(Typography.secondary)
                            .foregroundStyle(Theme.accent(for: colorScheme))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .accessibilityIdentifier(A11y.Workout.swapEntry)
                }

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
