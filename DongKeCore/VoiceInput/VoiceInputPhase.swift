import Foundation

public enum VoiceInputFailure: String, Equatable, Sendable, CaseIterable {
    case speechDenied
    case microphoneDenied
    case restricted
    case noRecognizer
    case onDeviceUnavailable
    case noSpeech
    case interrupted

    public var message: String {
        switch self {
        case .speechDenied:
            return "「语音识别」权限关着，说不了。去设置里打开它，或者直接用键盘输入。"
        case .microphoneDenied:
            return "「麦克风」权限关着，听不到你说话。去设置里打开它，键盘输入随时可用。"
        case .restricted:
            return "这台设备暂时不允许语音识别，先用键盘输入吧。"
        case .noRecognizer:
            return "中文语音识别现在不可用，先用键盘输入吧。"
        case .onDeviceUnavailable:
            return "这台设备没有中文离线语音包。可以允许联网识别，或者直接打字。"
        case .noSpeech:
            return "没听到说话。再点一次，或者直接打字。"
        case .interrupted:
            return "录音中断了，再点一次试试。"
        }
    }

    public var opensSettings: Bool {
        switch self {
        case .speechDenied, .microphoneDenied, .restricted:
            return true
        case .noRecognizer, .onDeviceUnavailable, .noSpeech, .interrupted:
            return false
        }
    }
}

public enum VoiceInputPhase: Equatable, Sendable {
    case idle
    case requestingAuthorization
    case awaitingOnlineConsent
    case listening
    case finished(String)
    case failed(VoiceInputFailure)

    public var isBusy: Bool {
        switch self {
        case .requestingAuthorization, .awaitingOnlineConsent, .listening:
            return true
        case .idle, .finished, .failed:
            return false
        }
    }

    public var isListening: Bool {
        self == .listening
    }

    public var failure: VoiceInputFailure? {
        if case .failed(let reason) = self { return reason }
        return nil
    }
}
