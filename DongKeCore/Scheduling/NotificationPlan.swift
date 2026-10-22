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

public enum ReminderPayload {
    public static let weekdayKey = "dk.weekday"
    public static let dayIndexKey = "dk.dayIndex"

    public static func userInfo(weekday: Weekday) -> [String: Int] {
        [weekdayKey: weekday.rawValue]
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
}
