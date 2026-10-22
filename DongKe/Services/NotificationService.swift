import Foundation
import UserNotifications
import DongKeCore

@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "dk.plan."

    private(set) var status: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0

    private init() {}

    var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "已允许"
        case .denied: "已拒绝"
        case .notDetermined: "未决定"
        @unknown default: "未知"
        }
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        status = settings.authorizationStatus
        let pending = await center.pendingNotificationRequests()
        scheduledCount = pending.filter { $0.identifier.hasPrefix(prefix) }.count
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshStatus()
    }

    #if DEBUG
    func requestProvisionalForTesting() async {
        _ = try? await center.requestAuthorization(options: [.provisional, .alert, .sound])
        await refreshStatus()
    }
    #endif

    func reschedule(plan: WorkoutPlan, settings: ReminderSettings) async {
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard settings.enabled else {
            await refreshStatus()
            return
        }

        for spec in ReminderPlanBuilder.build(plan: plan, settings: settings, now: Date()) {
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = settings.soundEnabled ? .default : nil

            let trigger = ReminderTrigger.from(spec)
            let components = DateComponents(hour: trigger.hour, minute: trigger.minute, weekday: trigger.weekday)
            let request = UNNotificationRequest(
                identifier: spec.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            try? await center.add(request)
        }

        await refreshStatus()
    }
}
