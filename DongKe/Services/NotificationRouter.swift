import Foundation
import UserNotifications
import DongKeCore

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
        [.banner, .sound]
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
