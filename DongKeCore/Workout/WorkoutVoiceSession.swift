import Foundation

@MainActor
public final class WorkoutVoiceSession {
    private let builder: WorkoutAnnouncementBuilder
    private let cues: SpeechCueCoordinator
    private var lastStepIndex: Int?
    private var lastCountdown: Int?
    private var lastExerciseName: String?
    private var isActive = false
    private var pendingPrompts: [TimedPrompt] = []
    private var firedPrompts: Set<Int> = []

    public var allowsEncouragement = false

    public init(plan: WorkoutPlan, dayIndex: Int, coordinator: SpeechCueCoordinator) {
        self.builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: dayIndex)
        self.cues = coordinator
    }

    public var lastSpokenText: String? {
        cues.lastSpokenText
    }

    public func start() {
        guard isActive == false else { return }
        isActive = true
        lastStepIndex = nil
        lastCountdown = nil
        cues.announce(builder.sessionStart())
    }

    public func stepChanged(to index: Int, silent: Bool = false) {
        guard isActive, index != lastStepIndex else { return }
        lastStepIndex = index
        guard silent == false, case .set? = builder.step(at: index) else { return }
        pendingPrompts = builder.prompts(at: index, allowsEncouragement: allowsEncouragement)
        firedPrompts = []
        let announcement = builder.announcement(forStepAt: index)
        if case let .setStart(name, _, _, _, _)? = announcement {
            lastExerciseName = name
        }
        cues.announce(announcement)
    }

    public func setElapsed(_ seconds: Int) {
        guard isActive, pendingPrompts.isEmpty == false else { return }
        let due = pendingPrompts.filter {
            $0.atSecond <= seconds && firedPrompts.contains($0.atSecond) == false
        }
        guard let latest = due.last else { return }
        for prompt in due { firedPrompts.insert(prompt.atSecond) }
        cues.announce(.setPrompt(latest.prompt))
    }

    public func restStarted(seconds: Int, at stepIndex: Int? = nil) {
        guard isActive else { return }
        lastCountdown = nil
        guard seconds > 0 else { return }
        if let stepIndex, let label = builder.nextActionLabel(afterBlockBreakAt: stepIndex) {
            cues.announce(.blockBreak(seconds: seconds, nextLabel: label))
        } else {
            cues.announce(.restStart(seconds: seconds))
        }
    }

    public func restTick(secondsLeft: Int) {
        guard isActive else { return }
        guard (1...3).contains(secondsLeft) else { return }
        guard secondsLeft != lastCountdown else { return }
        lastCountdown = secondsLeft
        cues.announce(.restCountdown(secondsLeft: secondsLeft))
    }

    public func restFinished(nextStepIndex: Int?) {
        guard isActive else { return }
        lastCountdown = nil
        let announcement = builder.restFinished(nextStepIndex: nextStepIndex)
        if case let .restFinished(nextName, _) = announcement, nextName == lastExerciseName {
            cues.announce(.restFinished(nextName: nil, nextDose: nil))
            return
        }
        cues.announce(announcement)
    }

    public func finished(completedSets: Int) {
        guard isActive else { return }
        isActive = false
        cues.announce(builder.finished(completedSets: completedSets))
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
