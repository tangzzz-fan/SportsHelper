import Foundation

@MainActor
public final class SpeechCueCoordinator {
    public var policy: SpeechCuePolicy {
        didSet {
            if policy.allowsSpeech == false {
                stop()
            }
        }
    }

    public private(set) var lastSpokenText: String?

    private let announcer: SpeechAnnouncing

    public init(policy: SpeechCuePolicy = SpeechCuePolicy(), announcer: SpeechAnnouncing) {
        self.policy = policy
        self.announcer = announcer
    }

    public var isSpeaking: Bool {
        announcer.isSpeaking
    }

    public func announce(_ announcement: WorkoutAnnouncement?) {
        guard policy.allowsSpeech, let announcement else { return }
        let text = announcement.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        lastSpokenText = text
        announcer.speak(text)
    }

    public func stop() {
        lastSpokenText = nil
        announcer.stop()
    }
}
