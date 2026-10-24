import Foundation

@MainActor
public final class WorkoutVoiceSession {
    private let builder: WorkoutAnnouncementBuilder
    private let cues: SpeechCueCoordinator
    private var lastStepIndex: Int?
    private var lastCountdown: Int?
    private var lastExerciseName: String?
    private var isActive = false

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
        let announcement = builder.announcement(forStepAt: index)
        if case let .setStart(name, _, _, _, _)? = announcement {
            lastExerciseName = name
        }
        cues.announce(announcement)
    }

    public func restStarted(seconds: Int, nextBlockTitle: String? = nil) {
        guard isActive else { return }
        lastCountdown = nil
        guard seconds > 0 else { return }
        if let nextBlockTitle, nextBlockTitle.isEmpty == false {
            cues.announce(.blockBreak(seconds: seconds, nextBlockTitle: nextBlockTitle))
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
        cues.stop()
    }
}
