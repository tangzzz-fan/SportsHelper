import Foundation

public enum SpeechPriority: Int, Comparable, Sendable {
    case aside = 0
    case instruction = 1
    case countdown = 2

    public static func < (lhs: SpeechPriority, rhs: SpeechPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SpeechRequest: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public let priority: SpeechPriority

    public init(id: UUID = UUID(), text: String, priority: SpeechPriority) {
        self.id = id
        self.text = text
        self.priority = priority
    }
}

public enum SpeechCancelReason: Equatable, Sendable {
    case replaced
    case preempted
    case stopped
    case interrupted
}

public enum SpeechFailure: Equatable, Sendable {
    case unavailable
    case engine
}

public enum SpeechOutputEvent: Equatable, Sendable {
    case started(UUID)
    case finished(UUID, seconds: Double)
    case cancelled(UUID, SpeechCancelReason)
    case failed(UUID, SpeechFailure)
}

public enum SpeechAvailability: Equatable, Sendable {
    case ready
    case needsDownload(bytes: Int64)
    case unsupported
}

public struct SpeechProfile: Equatable, Sendable {
    public let engineId: String
    public let voiceName: String
    public let charactersPerSecond: Double

    public init(engineId: String, voiceName: String, charactersPerSecond: Double) {
        self.engineId = engineId
        self.voiceName = voiceName
        self.charactersPerSecond = charactersPerSecond
    }

    public static let unavailable = SpeechProfile(engineId: "none", voiceName: "", charactersPerSecond: 0)
}

@MainActor
public protocol SpeechRendering: AnyObject {
    var availability: SpeechAvailability { get }
    var profile: SpeechProfile { get }

    func prepare()
    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void)
    func cancel()
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
