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
        let wantsStart = response.actionIdentifier == NotificationCategory.startTraining
        await MainActor.run {
            if wantsStart {
                self.requestStart(dayIndex: dayIndex)
            } else {
                self.openedDayIndex = dayIndex
            }
        }
    }

    /// 点「已开始」= 想练，不只是想看。手表没有计划，得让 iPhone 裁决出会话，
    /// 再把上下文发回来——这里发完就等，不等回执也不会卡住界面。
    private func requestStart(dayIndex: Int) {
        let revision = WatchContextModel.shared.planRevision
            ?? WatchContextModel.shared.context?.checkpoint.revision
            ?? 0
        WatchIntentSender.shared.send(
            WatchIntent(kind: .start, dayIndex: dayIndex, planRevision: revision)
        )
    }

    func consumeOpenedDay() -> Int? {
        defer { openedDayIndex = nil }
        return openedDayIndex
    }
}
