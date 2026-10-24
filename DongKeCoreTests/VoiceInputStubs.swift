import Foundation
@testable import DongKeCore

@MainActor
final class FakeSpeechTranscriber: SpeechTranscribing {
    var supportsOnDeviceRecognition = true
    var authorization: SpeechAuthorization = .authorized
    var authorizationAfterRequest: SpeechAuthorization = .authorized
    var startError: SpeechTranscriberError?
    var clearsStartErrorAfterThrow = false

    private(set) var requestCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0
    private(set) var onDeviceFlags: [Bool] = []

    private var events: ((SpeechEvent) -> Void)?

    func requestAuthorization() async -> SpeechAuthorization {
        requestCount += 1
        authorization = authorizationAfterRequest
        return authorizationAfterRequest
    }

    func start(onDevice: Bool, events: @escaping (SpeechEvent) -> Void) throws {
        startCount += 1
        onDeviceFlags.append(onDevice)
        if let error = startError {
            if clearsStartErrorAfterThrow { startError = nil }
            throw error
        }
        self.events = events
    }

    func stop() {
        stopCount += 1
        events = nil
    }

    func cancel() {
        cancelCount += 1
        events = nil
    }

    func emit(_ event: SpeechEvent) {
        events?(event)
    }

    func emitPartial(_ text: String) {
        emit(.partial(text))
    }

    func emitFinal(_ text: String) {
        emit(.final(text))
    }
}

@MainActor
final class VoiceTestClock {
    private(set) var current = Date(timeIntervalSince1970: 1_760_000_000)

    func advance(_ seconds: TimeInterval) {
        current += seconds
    }

    func now() -> Date {
        current
    }
}

@MainActor
func settle(_ rounds: Int = 6) async {
    for _ in 0..<rounds {
        await Task.yield()
    }
}
