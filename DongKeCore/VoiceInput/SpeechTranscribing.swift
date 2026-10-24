import Foundation

public enum SpeechAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case speechDenied
    case microphoneDenied
    case restricted

    public var isAuthorized: Bool {
        self == .authorized
    }
}

public enum SpeechEvent: Equatable, Sendable {
    case partial(String)
    case final(String)
    case onDeviceUnavailable
    case failed
}

public enum SpeechTranscriberError: Error, Equatable, Sendable {
    case onDeviceUnavailable
    case recognizerUnavailable
    case audioUnavailable
}

@MainActor
public protocol SpeechTranscribing: AnyObject {
    var supportsOnDeviceRecognition: Bool { get }
    var authorization: SpeechAuthorization { get }

    func requestAuthorization() async -> SpeechAuthorization
    func start(onDevice: Bool, events: @escaping (SpeechEvent) -> Void) throws
    func stop()
    func cancel()
}
