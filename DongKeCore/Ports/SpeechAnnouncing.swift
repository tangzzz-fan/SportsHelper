import Foundation

@MainActor
public protocol SpeechAnnouncing: AnyObject {
    var isSpeaking: Bool { get }
    func speak(_ text: String)
    func stop()
}

public struct SpeechCuePolicy: Equatable, Sendable {
    public var isEnabled: Bool
    public var isForeground: Bool
    public var isVoiceOverRunning: Bool

    public init(isEnabled: Bool = false, isForeground: Bool = false, isVoiceOverRunning: Bool = false) {
        self.isEnabled = isEnabled
        self.isForeground = isForeground
        self.isVoiceOverRunning = isVoiceOverRunning
    }

    public var allowsSpeech: Bool {
        isEnabled && isForeground && isVoiceOverRunning == false
    }
}
