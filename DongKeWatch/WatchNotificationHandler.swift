import Foundation
import Observation
import UserNotifications
import DongKeCore

/// Watch 上的通知落点。
///
/// iPhone 排的本地提醒会镜像到 Watch。点开时载荷里只有 `dayIndex` 和
/// `planRevision`——`sessionId` 要等 iPhone 那边真的开练才存在，在
/// `WatchContext` 快照里。所以这里不负责「打开某一节」，只把「用户点的是哪天」
/// 记下来，交给视图层和当前快照比对：
///
/// - 对得上：App 本来就在训练页，什么都不用做
/// - 对不上：用户点的是攒下来的旧通知，别把今天这节当它
///
/// 计划改版的情况不在这里管——`planRevision` 对不上时 `WatchWorkoutView`
/// 已经会显示阻断页（W2.5）。
@MainActor
@Observable
final class WatchNotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WatchNotificationHandler()

    /// 最近一次从通知点进来的 dayIndex。视图消费后置 nil。
    private(set) var openedDayIndex: Int?

    private override init() {
        super.init()
    }

    /// 必须早于任何通知回调注册，所以放在 App.init 里。
    func activate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(NotificationCategoryRegistry.all())
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let dayIndex = ReminderPayload.dayIndex(from: userInfo) else { return }
        await MainActor.run {
            self.openedDayIndex = dayIndex
        }
    }

    func consumeOpenedDay() -> Int? {
        defer { openedDayIndex = nil }
        return openedDayIndex
    }
}
