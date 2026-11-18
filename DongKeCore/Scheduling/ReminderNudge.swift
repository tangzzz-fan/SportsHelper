import Foundation

/// 一次「该练了」提醒与该次实际开练的对账样本。
public struct ReminderSample: Equatable, Sendable {
    public var weekday: Weekday
    /// 提醒本来响的时刻（当天的第几分钟）。
    public var reminderMinute: Int
    /// 实际开练的时刻。
    public var startMinute: Int

    public init(weekday: Weekday, reminderMinute: Int, startMinute: Int) {
        self.weekday = weekday
        self.reminderMinute = reminderMinute
        self.startMinute = startMinute
    }

    public var lateMinutes: Int { startMinute - reminderMinute }
}

/// 提醒时间跟着实际开练走。只在用户连着三次都晚很多的时候提一次，
/// 挪动幅度只有 15 / 30 两档，而且不越过他实际开练的时间。
public struct ReminderNudge: Equatable, Sendable {
    public var weekday: Weekday
    public var from: TimeOfDay
    public var to: TimeOfDay
    public var averageLateMinutes: Int
    public var sampleCount: Int

    public init(
        weekday: Weekday,
        from: TimeOfDay,
        to: TimeOfDay,
        averageLateMinutes: Int,
        sampleCount: Int
    ) {
        self.weekday = weekday
        self.from = from
        self.to = to
        self.averageLateMinutes = averageLateMinutes
        self.sampleCount = sampleCount
    }

    /// 拒绝记忆的键：同一个 weekday、同一个新时刻，拒过一次就不再提。
    public var fingerprint: String {
        "reminder.\(weekday.rawValue).\(to.stringValue)"
    }

    public var shiftMinutes: Int {
        to.minutesSinceMidnight - from.minutesSinceMidnight
    }
}

public enum ReminderNudgePlanner {
    /// 晚 40 分钟以上才算「这个点对你不合适」。20 分钟是正常误差。
    public static let latenessMinutes = 40
    public static let minimumSamples = 3
    /// 只挪这两档。挪得太多等于替用户重新安排作息。
    public static let steps = [15, 30]

    /// `samples` 按时间正序传进来；只看每个 weekday 最近的 `minimumSamples` 次。
    public static func propose(samples: [ReminderSample]) -> ReminderNudge? {
        for weekday in Weekday.allCases {
            let mine = samples.filter { $0.weekday == weekday }
            guard mine.count >= minimumSamples else { continue }

            let recent = Array(mine.suffix(minimumSamples))
            // 三次都晚 40 分钟以上：方向一致，才算稳定习惯，而不是某天加班。
            guard recent.allSatisfy({ $0.lateMinutes > latenessMinutes }) else { continue }

            let average = recent.reduce(0) { $0 + $1.lateMinutes } / recent.count
            // 只补一半，封顶 30、保底 15：一次挪到「刚好赶上你实际开练」，
            // 下一次就会变成提醒早了没人理——那比晚一点更糟。
            guard let step = steps.last(where: { $0 <= average / 2 }) else { continue }
            guard let last = recent.last else { continue }

            let base = last.reminderMinute
            guard let from = TimeOfDay(minutesSinceMidnight: base),
                  let to = TimeOfDay(minutesSinceMidnight: base + step) else { continue }

            return ReminderNudge(
                weekday: weekday,
                from: from,
                to: to,
                averageLateMinutes: average,
                sampleCount: recent.count
            )
        }
        return nil
    }
}
