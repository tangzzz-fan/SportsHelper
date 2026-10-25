import Foundation
import Testing
@testable import DongKeCore

@Suite("计划日历")
struct PlanCalendarTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ day: Int, hour: Int = 20) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }

    private var plan: WorkoutPlan {
        PlanGenerator.makePlan(profile: UserProfile(
            availableWeekdays: [.monday, .wednesday, .friday],
            sessionMinutes: 30
        ))
    }

    @Test("训练日就是当天那一节")
    func trainingDayIsToday() throws {
        let occurrence = try #require(PlanCalendar.occurrence(on: date(21), in: plan, calendar: calendar))
        #expect(occurrence.dayIndex == 3)
        #expect(calendar.isDate(occurrence.date, inSameDayAs: date(21)))
    }

    @Test("休息日取下一个训练日，不是本周第一节")
    func restDayTakesTheNextOne() throws {
        let occurrence = try #require(PlanCalendar.occurrence(on: date(20), in: plan, calendar: calendar))
        #expect(occurrence.dayIndex == 3, "周二的下一次应是周三，不是周一")
        #expect(calendar.isDate(occurrence.date, inSameDayAs: date(21)))
    }

    @Test("周日取下一周的周一")
    func sundayReachesNextWeek() throws {
        let occurrence = try #require(PlanCalendar.occurrence(on: date(25), in: plan, calendar: calendar))
        #expect(occurrence.dayIndex == 1)
        #expect(calendar.isDate(occurrence.date, inSameDayAs: date(26)))
    }

    @Test("一天都不练时没有可启动的一节")
    func noTrainingDays() {
        var rest = plan
        rest.days = rest.days.map { day in
            var copy = day
            copy.isRestDay = true
            copy.blocks = []
            return copy
        }
        #expect(PlanCalendar.occurrence(on: date(21), in: rest, calendar: calendar) == nil)
    }

    @Test("深链按离锚点最近的那一周归属")
    func deepLinkUsesNearestWeek() throws {
        let friday = try #require(PlanCalendar.occurrence(of: 3, anchoredAt: date(23), in: plan, calendar: calendar))
        #expect(calendar.isDate(friday.date, inSameDayAs: date(21)), "周五点周三那节，应归本周三")

        let monday = try #require(PlanCalendar.occurrence(of: 3, anchoredAt: date(19), in: plan, calendar: calendar))
        #expect(calendar.isDate(monday.date, inSameDayAs: date(21)))
    }

    @Test("提前练的那一节算到它自己那一天")
    func earlySessionBelongsToTheBorrowedDay() {
        let records = [
            SessionRecordSummary(date: date(25), plannedSets: 9, completedSets: 9, planDate: date(26))
        ]
        let sunday = PlanCalendar.occurrence(on: date(25), in: plan, calendar: calendar)
        #expect(sunday.map { HistoryStats.isDone($0, in: records, calendar: calendar) } == true)
        let nextMonday = PlanCalendar.occurrence(on: date(26), in: plan, calendar: calendar)
        #expect(nextMonday.map { HistoryStats.isDone($0, in: records, calendar: calendar) } == true)
    }

    @Test("上周一的记录不会把下周一算成已练")
    func lastWeeksSessionDoesNotCountForNextWeek() {
        let records = [
            SessionRecordSummary(date: date(19), plannedSets: 9, completedSets: 9, planDate: date(19))
        ]
        let nextMonday = PlanCalendar.occurrence(on: date(26), in: plan, calendar: calendar)
        #expect(nextMonday.map { HistoryStats.isDone($0, in: records, calendar: calendar) } == false)
    }

    @Test("周进度按计划日归属：周日提前练的记到下一周")
    func weeklyCountFollowsPlanDate() {
        let records = [
            SessionRecordSummary(date: date(25), plannedSets: 9, completedSets: 9, planDate: date(26))
        ]
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(25), calendar: calendar) == 0)
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(26), calendar: calendar) == 1)
    }

    @Test("没有 planDate 的旧记录照旧按发生日期算")
    func legacyRecordsFallBackToSessionDate() {
        let records = [
            SessionRecordSummary(date: date(21), plannedSets: 9, completedSets: 9)
        ]
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(22), calendar: calendar) == 1)
        let wednesday = PlanCalendar.occurrence(on: date(21), in: plan, calendar: calendar)
        #expect(wednesday.map { HistoryStats.isDone($0, in: records, calendar: calendar) } == true)
    }

    @Test("一天里练了两节，算两节")
    func twoSessionsOneDay() {
        let records = [
            SessionRecordSummary(date: date(21, hour: 8), plannedSets: 3, completedSets: 3, planDate: date(21)),
            SessionRecordSummary(date: date(21, hour: 19), plannedSets: 3, completedSets: 3, planDate: date(23))
        ]
        #expect(HistoryStats.completedDaysThisWeek(records, now: date(22), calendar: calendar) == 2)
    }
}
