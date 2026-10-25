import Foundation

@MainActor
public final class WorkoutVoiceSession {
    private let plan: WorkoutPlan
    private let dayIndex: Int
    private var builder: WorkoutAnnouncementBuilder
    private let cues: SpeechCueCoordinator
    private var lastStepIndex: Int?
    private var lastCountdown: Int?
    private var isActive = false
    /// 开场只念一次。`stop()` 会把 `isActive` 打回 false，但视图重建不能因此重念开场。
    private var didStart = false
    private var pendingPrompts: [TimedPrompt] = []
    private var firedPrompts: Set<Int> = []

    @MainActor
    public var level: VoiceLevel = .standard {
        didSet {
            guard level != oldValue else { return }
            if level == .quiet {
                cues.stop()
                return
            }
            if level.allowsRestCues == false { lastCountdown = nil }
        }
    }

    public init(plan: WorkoutPlan, dayIndex: Int, coordinator: SpeechCueCoordinator, steps: [FlowStep]? = nil) {
        self.plan = plan
        self.dayIndex = dayIndex
        self.builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: dayIndex, steps: steps)
        self.cues = coordinator
    }

    public func updateScript(_ steps: [FlowStep]) {
        builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: dayIndex, steps: steps)
    }

    public var lastSpokenText: String? {
        cues.lastSpokenText
    }

    /// 开始播报。`index` 是即将进入的那一步。
    ///
    /// 第一拍本身就是一组时**不念开场句**。调用方紧接着会 `stepChanged(to: index)`，
    /// 同一 tick 里两句并列，后到的 `setStart` 必然把开场句拦腰截断——真机上只听到
    /// 「开始训练，下……」然后立刻换句。「一拍一句」在 t=0 也必须成立，所以这里
    /// 让开场让位给「现在做什么」，当天主题交给屏幕。
    public func start(atStep index: Int) {
        guard didStart == false else { return }
        didStart = true
        isActive = true
        lastStepIndex = nil
        lastCountdown = nil
        // 静音档开课也要把 isActive 立起来：之后调回标准档时，
        // stepChanged 还能接上，不会整节课哑掉。
        guard level.isEnabled else { return }
        // 只有「整节课的第一拍」才配开场。恢复训练时 stepIndex > 0，
        // 那时候念「开始训练」是错的。
        guard index == 0 else { return }
        if case .set = builder.step(at: index) { return }
        cues.announce(builder.sessionStart())
    }

    public func stepChanged(to index: Int, silent: Bool = false) {
        guard isActive, level.isEnabled, index != lastStepIndex else { return }
        lastStepIndex = index
        guard silent == false, case .set? = builder.step(at: index) else { return }
        pendingPrompts = builder.prompts(at: index)
        firedPrompts = []
        cues.announce(builder.announcement(forStepAt: index))
    }

    public func setElapsed(_ seconds: Int) {
        guard isActive, level.allowsPrompts, pendingPrompts.isEmpty == false else { return }
        let due = pendingPrompts.filter {
            $0.atSecond <= seconds && firedPrompts.contains($0.atSecond) == false
        }
        guard let latest = due.last else { return }
        for prompt in due { firedPrompts.insert(prompt.atSecond) }
        cues.announce(.setPrompt(latest.prompt))
    }

    public func restStarted(seconds: Int, at stepIndex: Int? = nil) {
        guard isActive, level.allowsRestCues else { return }
        lastCountdown = nil
        guard seconds > 0 else { return }
        if let stepIndex, let label = builder.nextActionLabel(afterBlockBreakAt: stepIndex) {
            cues.announce(.blockBreak(seconds: seconds, nextLabel: label))
        } else {
            cues.announce(.restStart(seconds: seconds))
        }
    }

    public func restTick(secondsLeft: Int) {
        guard isActive, level.allowsRestCues else { return }
        guard (1...3).contains(secondsLeft) else { return }
        guard secondsLeft != lastCountdown else { return }
        lastCountdown = secondsLeft
        cues.announce(.restCountdown(secondsLeft: secondsLeft))
    }

    public func restFinished(nextStepIndex: Int?) {
        guard isActive, level.allowsRestCues else { return }
        lastCountdown = nil
        cues.announce(builder.restFinished(nextStepIndex: nextStepIndex))
    }

    public func finished(completedSets: Int, extraSets: Int = 0) {
        guard isActive, level.isEnabled else { return }
        isActive = false
        cues.announce(builder.finished(completedSets: completedSets, extraSets: extraSets))
    }

    public func stop() {
        isActive = false
        lastStepIndex = nil
        lastCountdown = nil
        pendingPrompts = []
        firedPrompts = []
        cues.stop()
    }
}
