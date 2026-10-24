#if DEBUG
import Foundation
import DongKeCore

@MainActor
final class ScriptedSpeechTranscriber: SpeechTranscribing {
    enum Script: Equatable {
        case success(String)
        case silenceDenied
        case microphoneDenied
        case restricted
        case onDeviceMissing(online: String)
        case empty
        case stall

        init(named name: String) {
            switch name {
            case "denySpeech": self = .silenceDenied
            case "denyMic": self = .microphoneDenied
            case "restricted": self = .restricted
            case "onDeviceMissing": self = .onDeviceMissing(online: "每周二四，每次 45 分钟，在家用哑铃增肌")
            case "empty": self = .empty
            case "stall": self = .stall
            default: self = .success("每周二四练，每次 45 分钟")
            }
        }
    }

    private let script: Script
    private var events: ((SpeechEvent) -> Void)?

    init(script: Script) {
        self.script = script
    }

    var supportsOnDeviceRecognition: Bool {
        if case .onDeviceMissing = script { return false }
        return true
    }

    var authorization: SpeechAuthorization {
        switch script {
        case .silenceDenied: return .speechDenied
        case .microphoneDenied: return .microphoneDenied
        case .restricted: return .restricted
        default: return .authorized
        }
    }

    func requestAuthorization() async -> SpeechAuthorization {
        authorization
    }

    func start(onDevice: Bool, events: @escaping (SpeechEvent) -> Void) throws {
        if case .onDeviceMissing = script, onDevice {
            throw SpeechTranscriberError.onDeviceUnavailable
        }
        self.events = events
        switch script {
        case .success(let text), .onDeviceMissing(let text):
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                events(.partial(String(text.prefix(6))))
                try? await Task.sleep(for: .milliseconds(120))
                events(.final(text))
            }
        case .empty:
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                events(.final(""))
            }
        case .stall, .silenceDenied, .microphoneDenied, .restricted:
            break
        }
    }

    func stop() {
        events = nil
    }

    func cancel() {
        events = nil
    }
}
#endif
