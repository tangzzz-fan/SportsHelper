import Foundation

#if canImport(UserNotifications)
import UserNotifications

/// 通知分类的唯一定义处。
///
/// iPhone 排程时把 `categoryIdentifier` 写进 content，Watch 拿到的是镜像通知。
/// 两边必须注册同一份：iPhone 少了它，通知上不出现「已开始」；Watch 少了它，
/// 按钮点下去没有回调，用户以为按坏了。
public enum NotificationCategoryRegistry {
    public static func all() -> Set<UNNotificationCategory> {
        let start = UNNotificationAction(
            identifier: NotificationCategory.startTraining,
            title: "已开始",
            options: [.foreground]
        )
        return [
            UNNotificationCategory(
                identifier: NotificationCategory.workout,
                actions: [start],
                intentIdentifiers: []
            )
        ]
    }
}
#endif
