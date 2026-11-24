import Foundation
import Testing
@testable import DongKeCore

@Suite("续练选择页的判据")
struct ResumePromptTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    /// 固定中午，`updatedMinutesAgo` 取几小时也不会滑到前一天。
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12))!
    }

    private func checkpoint(
        stepIndex: Int = 3,
        minutesAgo: Double = 30,
        restEndsIn: TimeInterval? = nil,
        revision: Int = 1,
        status: WorkoutCheckpoint.WorkoutStatus = .inProgress
    ) -> WorkoutCheckpoint {
        WorkoutCheckpoint(
            sessionId: UUID(),
            dayIndex: 1,
            stepIndex: stepIndex,
            totalSteps: 12,
            startedAt: now.addingTimeInterval(-3600),
            updatedAt: now.addingTimeInterval(-minutesAgo * 60),
            restEndsAt: restEndsIn.map { now.addingTimeInterval($0) },
            revision: revision,
            status: status
        )
    }

    @Test("练过一组、离开半小时：要问")
    func asksAfterBreak() {
        #expect(
            ResumePrompt.shouldAsk(
                checkpoint: checkpoint(), currentPlanRevision: 1, now: now, calendar: calendar
            )
        )
    }

    @Test("刚离开三分钟：不问，别打断")
    func quietWhenJustLeft() {
        #expect(
            !ResumePrompt.shouldAsk(
                checkpoint: checkpoint(minutesAgo: 3),
                currentPlanRevision: 1,
                now: now,
                calendar: calendar
            )
        )
    }

    @Test("一组都没练：不问，新会话没什么好选的")
    func quietOnFreshSession() {
        #expect(
            !ResumePrompt.shouldAsk(
                checkpoint: checkpoint(stepIndex: 0),
                currentPlanRevision: 1,
                now: now,
                calendar: calendar
            )
        )
    }

    @Test("还在组间休息：不问，那时该看倒计时")
    func quietDuringRest() {
        #expect(
            !ResumePrompt.shouldAsk(
                checkpoint: checkpoint(restEndsIn: 60),
                currentPlanRevision: 1,
                now: now,
                calendar: calendar
            )
        )
    }

    @Test("已结束或已放弃的断点不问")
    func quietWhenFinished() {
        for status in [WorkoutCheckpoint.WorkoutStatus.completed, .abandoned] {
            #expect(
                !ResumePrompt.shouldAsk(
                    checkpoint: checkpoint(status: status),
                    currentPlanRevision: 1,
                    now: now,
                    calendar: calendar
                )
            )
        }
    }

    @Test("计划改版了不问，改版的阻断优先")
    func quietWhenPlanChanged() {
        #expect(
            !ResumePrompt.shouldAsk(
                checkpoint: checkpoint(revision: 1),
                currentPlanRevision: 2,
                now: now,
                calendar: calendar
            )
        )
    }

    @Test("revision 还不知道时按没改版处理")
    func asksWhenRevisionUnknown() {
        #expect(
            ResumePrompt.shouldAsk(
                checkpoint: checkpoint(), currentPlanRevision: nil, now: now, calendar: calendar
            )
        )
    }

    @Test("跨天的断点不问，只有当天算数")
    func quietNextDay() {
        var stale = checkpoint()
        stale.updatedAt = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(
            !ResumePrompt.shouldAsk(
                checkpoint: stale, currentPlanRevision: 1, now: now, calendar: calendar
            )
        )
    }

    @Test("阈值边界：差一秒不问，到点就问")
    func thresholdBoundary() {
        let justUnder = ResumePrompt.defaultThreshold - 1
        #expect(
            !ResumePrompt.shouldAsk(
                checkpoint: checkpoint(minutesAgo: justUnder / 60),
                currentPlanRevision: 1,
                now: now,
                calendar: calendar
            )
        )
        #expect(
            ResumePrompt.shouldAsk(
                checkpoint: checkpoint(minutesAgo: ResumePrompt.defaultThreshold / 60),
                currentPlanRevision: 1,
                now: now,
                calendar: calendar
            )
        )
    }
}
