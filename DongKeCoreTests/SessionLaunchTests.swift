import Foundation
import Testing
@testable import DongKeCore

@Suite("会话裁决：谁有权决定当前是哪一次")
struct SessionLaunchTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }()

    /// 2026-11-25 是周三。计划里周三（dayIndex 3）和周五（5）练，其余休息。
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 20))!
    }

    private var thursday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 20))!
    }

    private var plan: WorkoutPlan {
        let blocks = [makeBlock(items: [makeItem()])]
        return makePlan(days: Weekday.allCases.map { weekday in
            let training = weekday == .wednesday || weekday == .friday
            return makeDay(
                index: weekday.rawValue,
                rest: !training,
                blocks: training ? blocks : []
            )
        })
    }

    private func checkpoint(
        sessionId: UUID = UUID(),
        dayIndex: Int = 3,
        stepIndex: Int = 2,
        updatedAt: Date? = nil,
        revision: Int = 1,
        status: WorkoutCheckpoint.WorkoutStatus = .inProgress
    ) -> WorkoutCheckpoint {
        WorkoutCheckpoint(
            sessionId: sessionId,
            dayIndex: dayIndex,
            stepIndex: stepIndex,
            totalSteps: 10,
            startedAt: now,
            updatedAt: updatedAt ?? now,
            revision: revision,
            status: status
        )
    }

    private func liveSession(
        id: UUID = UUID(),
        dayIndex: Int = 3,
        startedAt: Date? = nil
    ) -> ActiveSession {
        ActiveSession(id: id, dayIndex: dayIndex, startedAt: startedAt ?? now)
    }

    private func resolve(
        _ intent: SessionIntent,
        active: ActiveSession? = nil,
        stored: WorkoutCheckpoint? = nil,
        at moment: Date? = nil,
        plan source: WorkoutPlan? = nil
    ) -> SessionLaunch {
        SessionLaunchResolver.resolve(
            intent: intent,
            active: active,
            stored: stored,
            plan: source ?? plan,
            now: moment ?? now,
            calendar: calendar
        )
    }

    // MARK: - 今日页

    @Test("今天还没有会话：新建今天那节")
    func startTodayCreatesToday() {
        #expect(resolve(.startToday) == .create(dayIndex: 3, origin: .phone))
    }

    @Test("今天已经在练：不要再建一个")
    func startTodayOpensLiveSession() {
        let live = liveSession()
        #expect(resolve(.startToday, active: live) == .open(live.id))
    }

    @Test("昨天那个会话还开着：不认它，重新建今天的")
    func startTodayIgnoresSessionFromYesterday() {
        let stale = liveSession(startedAt: calendar.date(byAdding: .day, value: -1, to: now))
        #expect(resolve(.startToday, active: stale) == .create(dayIndex: 3, origin: .phone))
    }

    @Test("今天是休息日：开计划里下一节，跟今日页原来的行为一致")
    func startTodayFallsToNextTrainingDay() {
        #expect(resolve(.startToday, at: thursday) == .create(dayIndex: 5, origin: .phone))
    }

    // MARK: - 点通知

    @Test("点通知时今天已经在练，通知说的又是别的一天：认当前这个")
    func reminderKeepsLiveSessionWhenNotificationIsStale() {
        let live = liveSession(dayIndex: 3)
        #expect(resolve(.openReminder(dayIndex: 5), active: live) == .open(live.id))
    }

    @Test("点通知时断点正好是那一天：续上，不要新建")
    func reminderResumesMatchingCheckpoint() {
        let stored = checkpoint(dayIndex: 3)
        #expect(resolve(.openReminder(dayIndex: 3), stored: stored) == .resume(stored))
    }

    @Test("点通知时断点是另一天：建通知说的那天")
    func reminderCreatesWhenCheckpointIsAnotherDay() {
        let stored = checkpoint(dayIndex: 3)
        #expect(resolve(.openReminder(dayIndex: 5), stored: stored) == .create(dayIndex: 5, origin: .phone))
    }

    @Test("断点是昨天的：不能续，建今天这节")
    func reminderCreatesWhenCheckpointExpired() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let stored = checkpoint(dayIndex: 3, updatedAt: yesterday)
        #expect(resolve(.openReminder(dayIndex: 3), stored: stored) == .create(dayIndex: 3, origin: .phone))
    }

    @Test("断点来自改版前的计划：不能续，建新会话")
    func reminderCreatesWhenPlanChanged() {
        let stored = checkpoint(dayIndex: 3, revision: 2)
        #expect(resolve(.openReminder(dayIndex: 3), stored: stored) == .create(dayIndex: 3, origin: .phone))
    }

    @Test("断点已经结束：不能续")
    func reminderCreatesWhenCheckpointFinished() {
        let stored = checkpoint(dayIndex: 3, status: .completed)
        #expect(resolve(.openReminder(dayIndex: 3), stored: stored) == .create(dayIndex: 3, origin: .phone))
    }

    @Test("通知说的是休息日：挡住，不要凭空建一天")
    func reminderBlocksRestDay() {
        #expect(resolve(.openReminder(dayIndex: 4)) == .blocked(.unknownDay))
    }

    // MARK: - 手表「已开始」

    @Test("手表点开始，今天已经在练：续上当前这个")
    func watchStartOpensLiveSession() {
        let live = liveSession(dayIndex: 3)
        #expect(resolve(.watchStart(dayIndex: 5), active: live) == .open(live.id))
    }

    @Test("手表点开始，有可续断点：续断点，哪怕载荷说的是别的一天")
    func watchStartResumesResumableCheckpoint() {
        let stored = checkpoint(dayIndex: 3)
        #expect(resolve(.watchStart(dayIndex: 5), stored: stored) == .resume(stored))
    }

    @Test("手表点开始，什么都没：建载荷指的那天，来源记成手表")
    func watchStartCreatesGivenDay() {
        #expect(resolve(.watchStart(dayIndex: 5)) == .create(dayIndex: 5, origin: .watch))
    }

    @Test("手表不知道哪天：建今天这节")
    func watchStartWithoutDayCreatesToday() {
        #expect(resolve(.watchStart(dayIndex: nil)) == .create(dayIndex: 3, origin: .watch))
    }

    @Test("手表不知道哪天，今天又休息：跟今日页一样开下一节")
    func watchStartWithoutDayFallsToNextTrainingDay() {
        #expect(resolve(.watchStart(dayIndex: nil), at: thursday) == .create(dayIndex: 5, origin: .watch))
    }

    @Test("手表说了一个休息日：挡住")
    func watchStartBlocksRestDay() {
        #expect(resolve(.watchStart(dayIndex: 4)) == .blocked(.unknownDay))
    }

    // MARK: - 手表「重新开始」

    @Test("要放弃的就是正在练的：放弃后新建")
    func restartAbandonsMatchingLiveSession() {
        let live = liveSession(dayIndex: 3)
        #expect(
            resolve(.watchRestart(dayIndex: 3, sessionId: live.id), active: live)
                == .abandonAndCreate(abandon: live.id, dayIndex: 3, origin: .watch)
        )
    }

    @Test("内存里没有，但断点就是要放弃的那个：放弃后新建")
    func restartAbandonsMatchingStoredCheckpoint() {
        let stored = checkpoint(dayIndex: 3)
        #expect(
            resolve(.watchRestart(dayIndex: 3, sessionId: stored.sessionId), stored: stored)
                == .abandonAndCreate(abandon: stored.sessionId, dayIndex: 3, origin: .watch)
        )
    }

    @Test("要放弃的已经不是当前会话：这条意图处理过了，不要再放弃一次")
    func restartIgnoresStaleIntent() {
        let live = liveSession(dayIndex: 3)
        #expect(
            resolve(.watchRestart(dayIndex: 3, sessionId: UUID()), active: live)
                == .blocked(.staleRestart)
        )
    }

    @Test("什么都没有还要重开：算过期意图")
    func restartBlocksWhenNothingExists() {
        #expect(resolve(.watchRestart(dayIndex: 3, sessionId: UUID())) == .blocked(.staleRestart))
    }

    @Test("重开的是休息日：先挡住，别拿脏 dayIndex 建会话")
    func restartBlocksRestDay() {
        let live = liveSession(dayIndex: 3)
        #expect(
            resolve(.watchRestart(dayIndex: 4, sessionId: live.id), active: live)
                == .blocked(.unknownDay)
        )
    }

    // MARK: - 等待态

    @Test("等到 8 秒还没拿到新上下文才算超时")
    func restartWaitTimesOutAtEightSeconds() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let waiting = RestartWaitState.waiting(startedAt: start)
        #expect(waiting.hasTimedOut(at: start.addingTimeInterval(7.9)) == false)
        #expect(waiting.hasTimedOut(at: start.addingTimeInterval(8.1)) == true)
    }

    @Test("只有等待态会超时，空闲和失败都不该被时间影响")
    func onlyWaitingCanTimeOut() {
        #expect(RestartWaitState.idle.hasTimedOut(at: Date()) == false)
        #expect(RestartWaitState.failed.hasTimedOut(at: Date()) == false)
    }
}
