import Foundation

public struct RestEndNotification: Equatable, Sendable {
    public var identifier: String
    public var dayIndex: Int
    public var fireAt: Date
    public var title: String
    public var body: String

    public init(identifier: String, dayIndex: Int, fireAt: Date, title: String, body: String) {
        self.identifier = identifier
        self.dayIndex = dayIndex
        self.fireAt = fireAt
        self.title = title
        self.body = body
    }
}

public enum RestNotificationBuilder {
    public static let prefix = "dk.rest."

    public static func make(
        dayIndex: Int,
        sessionId: UUID,
        endsAt: Date,
        nextTitle: String
    ) -> RestEndNotification {
        RestEndNotification(
            identifier: prefix + sessionId.uuidString.lowercased(),
            dayIndex: dayIndex,
            fireAt: endsAt,
            title: "休息结束",
            body: "\(nextTitle)，接着练"
        )
    }
}

/// 通知分类与动作。iPhone 排程时写进 content，两端都要注册同一份，
/// 否则 Watch 镜像过来的通知上不会出现按钮。
public enum NotificationCategory {
    public static let workout = "dk.workout"
    /// 「已开始」：从通知直接进训练页。
    public static let startTraining = "dk.startTraining"
}

public enum ReminderPayload {
    public static let weekdayKey = "dk.weekday"
    public static let dayIndexKey = "dk.dayIndex"
    public static let planRevisionKey = "dk.planRevision"

    public static func userInfo(weekday: Weekday) -> [String: Int] {
        [weekdayKey: weekday.rawValue]
    }

    /// 每日提醒的完整载荷。三个键一起带，各有各的用处：
    /// - `weekday`：升级前装着的包只认它。留着，别让老版本点不开
    /// - `dayIndex`：新版的落点。不再靠「今天星期几」反推——跨午夜挪过的提醒会推错天
    /// - `planRevision`：判断这条通知是不是计划改版之前排的，Watch 侧据此决定要不要拦
    public static func userInfo(weekday: Weekday, dayIndex: Int, planRevision: Int) -> [String: Int] {
        [
            weekdayKey: weekday.rawValue,
            dayIndexKey: dayIndex,
            planRevisionKey: planRevision,
        ]
    }

    public static func weekday(from userInfo: [AnyHashable: Any]) -> Weekday? {
        if let value = userInfo[weekdayKey] as? Int {
            return Weekday(rawValue: value)
        }
        if let value = userInfo[weekdayKey] as? NSNumber {
            return Weekday(rawValue: value.intValue)
        }
        return nil
    }

    public static func userInfo(dayIndex: Int) -> [String: Int] {
        [dayIndexKey: dayIndex]
    }

    public static func dayIndex(from userInfo: [AnyHashable: Any]) -> Int? {
        if let value = userInfo[dayIndexKey] as? Int {
            return value
        }
        if let value = userInfo[dayIndexKey] as? NSNumber {
            return value.intValue
        }
        return nil
    }

    public static func planRevision(from userInfo: [AnyHashable: Any]) -> Int? {
        if let value = userInfo[planRevisionKey] as? Int {
            return value
        }
        if let value = userInfo[planRevisionKey] as? NSNumber {
            return value.intValue
        }
        return nil
    }
}
