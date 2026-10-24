import Foundation

public enum VoiceInputCopy {
    public static let actionStart = "说一句"
    public static let actionStop = "停，用这段"
    public static let actionCancel = "取消"
    public static let openSettings = "去设置"
    public static let capHint = "最多 \(Int(VoiceInputLimit.maxDuration)) 秒，\(VoiceInputLimit.maxCharacters) 字以内"
    public static let privacy = "不保存录音，只把识别出的文字填进输入框。"
    public static let listeningHint = "正在听…说完点「停，用这段」"
    public static let onlineTitle = "这台设备没有离线中文识别"
    public static let onlineBody = "继续会用 Apple 的语音服务转写：录音由 Apple 处理，本 App 不保存音频，只留文字。也可以改用键盘输入。"
    public static let onlineAccept = "允许联网识别"
    public static let onlineDecline = "改用键盘"
    public static let permissionTitle = "用语音说一句"
    public static let permissionBody = "需要「语音识别」和「麦克风」两项权限。录音只在本机转成文字，不会上传到我们的服务器。"
    public static let settingsHint = "在「设置 → 动刻」里可以打开这两项权限。"
}
