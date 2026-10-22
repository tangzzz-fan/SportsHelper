import Foundation
import UserNotifications
import DongKeCore

@MainActor
protocol RestNotificationScheduling: AnyObject {
    func scheduleRestEnd(dayIndex: Int, sessionId: UUID, endsAt: Date, nextTitle: String)
    func cancelRestEnd()
}

@MainActor
@Observable
final class NotificationService: RestNotificationScheduling {
    static let shared = NotificationService()

    let router = NotificationRouter()

    private let center = UNUserNotificationCenter.current()
    private let prefix = "dk.plan."

    private(set) var status: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0

    private init() {
        center.delegate = router
    }

    var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: "已允许"
        case .denied: "已拒绝"
        case .notDetermined: "未决定"
        @unknown default: "未知"
        }
    }

    var reminderAuthorization: ReminderAuthorization {
        switch status {
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
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
            content.userInfo = ReminderPayload.userInfo(weekday: spec.weekday)

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

    func scheduleRestEnd(dayIndex: Int, sessionId: UUID, endsAt: Date, nextTitle: String) {
        Task { await scheduleRestEndNow(dayIndex: dayIndex, sessionId: sessionId, endsAt: endsAt, nextTitle: nextTitle) }
    }

    func cancelRestEnd() {
        Task { await cancelRestEndNow() }
    }

    func removeAllOwned() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) || $0.hasPrefix(RestNotificationBuilder.prefix) }
        guard identifiers.isEmpty == false else {
            await refreshStatus()
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        await refreshStatus()
    }

    private func scheduleRestEndNow(dayIndex: Int, sessionId: UUID, endsAt: Date, nextTitle: String) async {
        await cancelRestEndNow()
        let spec = RestNotificationBuilder.make(
            dayIndex: dayIndex,
            sessionId: sessionId,
            endsAt: endsAt,
            nextTitle: nextTitle
        )
        let seconds = spec.fireAt.timeIntervalSinceNow
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.body
        content.sound = .default
        content.userInfo = ReminderPayload.userInfo(dayIndex: spec.dayIndex)

        let request = UNNotificationRequest(
            identifier: spec.identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        try? await center.add(request)
        await refreshStatus()
    }

    private func cancelRestEndNow() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(RestNotificationBuilder.prefix) }
        guard identifiers.isEmpty == false else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        await refreshStatus()
    }
}
