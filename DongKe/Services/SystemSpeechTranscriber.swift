import AVFoundation
import Speech
import DongKeCore

@MainActor
final class SystemSpeechTranscriber: SpeechTranscribing {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isTapping = false

    var supportsOnDeviceRecognition: Bool {
        recognizer?.supportsOnDeviceRecognition ?? false
    }

    var authorization: SpeechAuthorization {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let microphone = AVAudioApplication.shared.recordPermission
        if speech == .denied { return .speechDenied }
        if speech == .restricted { return .restricted }
        if microphone == .denied { return .microphoneDenied }
        if speech == .authorized && microphone == .granted { return .authorized }
        return .notDetermined
    }

    func requestAuthorization() async -> SpeechAuthorization {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await requestSpeechPermission()
        }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        return authorization
    }

    func start(onDevice: Bool, events: @escaping (SpeechEvent) -> Void) throws {
        stop()
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = onDevice
        request.taskHint = .dictation
        request.addsPunctuation = true
        self.request = request

        try activateSession()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw SpeechTranscriberError.audioUnavailable }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            request.append(buffer)
        }
        isTapping = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
            throw SpeechTranscriberError.audioUnavailable
        }

        task = recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failure = error
            Task { @MainActor in
                if let text, isFinal {
                    events(.final(text))
                } else if let text {
                    events(.partial(text))
                }
                if let failure {
                    events(Self.event(for: failure, wasOnDevice: onDevice))
                }
            }
        }
    }

    func stop() {
        engine.stop()
        if isTapping {
            engine.inputNode.removeTap(onBus: 0)
            isTapping = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        deactivateSession()
    }

    func cancel() {
        stop()
    }

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func requestSpeechPermission() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in
                continuation.resume()
            }
        }
    }

    private static func event(for error: Error, wasOnDevice: Bool) -> SpeechEvent {
        let ns = error as NSError
        let offlineMissingCodes = [1101, 1107]
        let isOfflineMissing = offlineMissingCodes.contains(ns.code)
            && (ns.domain == "kAFAssistantErrorDomain" || ns.domain == "kLSRErrorDomain")
        if wasOnDevice && isOfflineMissing {
            return .onDeviceUnavailable
        }
        return .failed
    }
}
