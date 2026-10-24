import Foundation
import DongKeCore

@MainActor
enum VoiceInputService {
    static func makeMachine() -> VoiceInputMachine {
        VoiceInputMachine(
            transcribing: makeTranscriber(),
            hasConsentedToOnline: OnlineSpeechConsent.shared.isGranted,
            consentRecorder: { OnlineSpeechConsent.shared.isGranted = $0 }
        )
    }

    private static func makeTranscriber() -> SpeechTranscribing {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let transcript = environment["DK_VOICE_TRANSCRIPT"] {
            return ScriptedSpeechTranscriber(script: .success(transcript))
        }
        if let name = environment["DK_VOICE_STUB"] {
            return ScriptedSpeechTranscriber(script: ScriptedSpeechTranscriber.Script(named: name))
        }
        #endif
        return SystemSpeechTranscriber()
    }
}

@MainActor
final class OnlineSpeechConsent {
    static let shared = OnlineSpeechConsent()

    private let key = "dk.voice.onlineConsent"

    var isGranted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
