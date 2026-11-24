import Foundation

/// 手表要求 iPhone 做一件与「当前会话」有关的事。
///
/// 手表没有计划，也造不出会话——`WatchContext` 里只有正在进行的那一次。
/// 所以「开始」和「重新开始」都得由 iPhone 裁决，这里只负责把意图送过去。
public struct WatchIntent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case start
        case restart
    }

    /// 超过这个岁数就不再执行。`transferUserInfo` 会排队，用户可能几小时后才
    /// 和 iPhone 重新连上——那时「开始练」早就没意义了。
    public static let maxAge: TimeInterval = 5 * 60

    public var kind: Kind
    /// `start` 用：通知载荷里的那一天。点了正文而没走通知时为 nil。
    public var dayIndex: Int?
    /// `restart` 用：手表看到的那一次会话。iPhone 靠它分辨意图是否已经生效过。
    public var sessionId: UUID?
    public var planRevision: Int
    public var createdAt: Date

    public init(
        kind: Kind,
        dayIndex: Int? = nil,
        sessionId: UUID? = nil,
        planRevision: Int,
        createdAt: Date = Date()
    ) {
        self.kind = kind
        self.dayIndex = dayIndex
        self.sessionId = sessionId
        self.planRevision = planRevision
        self.createdAt = createdAt
    }

    public func isExpired(now: Date = Date()) -> Bool {
        now.timeIntervalSince(createdAt) > Self.maxAge
    }

    /// 转成裁决器的输入。`restart` 缺参数时返回 nil——那种载荷是坏的，不该猜。
    public var sessionIntent: SessionIntent? {
        switch kind {
        case .start:
            return .watchStart(dayIndex: dayIndex)
        case .restart:
            guard let dayIndex, let sessionId else { return nil }
            return .watchRestart(dayIndex: dayIndex, sessionId: sessionId)
        }
    }
}

/// iPhone 对一条意图的裁决结果。
///
/// 只说「做了什么」，不携带会话内容：内容永远以 `WatchContext` 为准。
/// 回执说成功但 steps 还没到，手表拿旧 steps 记组就会写错会话。
public struct WatchIntentAck: Codable, Equatable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case opened
        case resumed
        case created
        case restarted
        case blocked
        case ignored
    }

    public var outcome: Outcome
    /// `blocked` 时说明原因。
    public var block: SessionLaunchBlock?

    public init(outcome: Outcome, block: SessionLaunchBlock? = nil) {
        self.outcome = outcome
        self.block = block
    }

    public init(_ launch: SessionLaunch) {
        switch launch {
        case .open:
            self.init(outcome: .opened)
        case .resume:
            self.init(outcome: .resumed)
        case .create:
            self.init(outcome: .created)
        case .abandonAndCreate:
            self.init(outcome: .restarted)
        case let .blocked(block):
            self.init(outcome: .blocked, block: block)
        }
    }
}
