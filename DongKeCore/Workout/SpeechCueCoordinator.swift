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
    public private(set) var activeRequest: SpeechRequest?

    private let renderer: SpeechRendering

    public init(policy: SpeechCuePolicy = SpeechCuePolicy(), renderer: SpeechRendering) {
        self.policy = policy
        self.renderer = renderer
    }

    public var isSpeaking: Bool {
        activeRequest != nil
    }

    public var profile: SpeechProfile {
        renderer.profile
    }

    public func announce(_ announcement: WorkoutAnnouncement?) {
        guard policy.allowsSpeech, let announcement else { return }
        let text = announcement.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }

        let request = SpeechRequest(text: text, priority: announcement.priority)
        if let current = activeRequest, request.priority < current.priority {
            return
        }
        if activeRequest != nil {
            renderer.cancel()
        }
        activeRequest = request
        lastSpokenText = text
        renderer.render(request) { [weak self] event in
            self?.receive(event)
        }
    }

    public func stop() {
        activeRequest = nil
        lastSpokenText = nil
        renderer.cancel()
    }

    private func receive(_ event: SpeechOutputEvent) {
        guard let current = activeRequest else { return }
        switch event {
        case .started:
            break
        case let .finished(id, _), let .cancelled(id, _), let .failed(id, _):
            guard id == current.id else { return }
            activeRequest = nil
        }
    }

}
