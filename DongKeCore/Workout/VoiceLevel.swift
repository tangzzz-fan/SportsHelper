import Foundation

/// 播报档位。行业里这是用户可调的滑杆（Peloton 的 Custom Audio、NTC 的三档声音），
/// 不是设计选择题——用户对「说多少」的容忍度差异极大。
public enum VoiceLevel: String, CaseIterable, Sendable {
    /// 一句话都不说。
    case quiet
    /// 只报「做什么、多少」：开场、每组开始、结束。休息与倒数全部沉默。
    case minimal
    /// 在 minimal 之上加休息开始、跨区块休息、倒数 3/2/1、首组要点。
    case standard

    public var isEnabled: Bool {
        self != .quiet
    }

    /// 休息类播报（休息开始 / 跨区块 / 倒数）是否出声。
    public var allowsRestCues: Bool {
        self == .standard
    }

    /// 动作中的提示（中段要点、剩余秒数）是否出声。
    public var allowsPrompts: Bool {
        self == .standard
    }

    public var label: String {
        switch self {
        case .quiet: "静音"
        case .minimal: "精简"
        case .standard: "标准"
        }
    }

    public var detail: String {
        switch self {
        case .quiet: "训练全程不发声"
        case .minimal: "只报每组做什么、多少；休息与倒数不出声"
        case .standard: "再加休息开始、最后 3 秒倒数、首组动作要点"
        }
    }
}
