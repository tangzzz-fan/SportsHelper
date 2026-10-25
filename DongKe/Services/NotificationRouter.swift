import Foundation
import UserNotifications
import DongKeCore
import os

private let notifLog = Logger(subsystem: "app.dongke.ios", category: "notifications")

enum WorkoutDeepLink: Equatable, Sendable {
    case dayIndex(Int)
    case weekday(Weekday)
}

@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    var onOpenWorkout: ((WorkoutDeepLink) -> Void)?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 组间休息归零：前台已经有触觉 + 播报，再弹横幅并播提示音就是第四遍，
        // 而且提示音会盖在播报上。后台才需要它（那时没有 TTS）。
        if notification.request.identifier.hasPrefix(RestNotificationBuilder.prefix) {
            notifLog.notice("willPresent rest-end suppressed id=\(notification.request.identifier, privacy: .public)")
            return []
        }
        notifLog.notice("willPresent banner id=\(notification.request.identifier, privacy: .public)")
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let link: WorkoutDeepLink?
        if let dayIndex = ReminderPayload.dayIndex(from: userInfo) {
            link = .dayIndex(dayIndex)
        } else if let weekday = ReminderPayload.weekday(from: userInfo) {
            link = .weekday(weekday)
        } else {
            link = nil
        }
        guard let link else { return }
        await MainActor.run {
            self.onOpenWorkout?(link)
        }
    }
}
