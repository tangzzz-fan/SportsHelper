import Foundation
import Testing
@testable import DongKeCore

@Suite("WeeklyScheduleGenerator")
struct WeeklyScheduleGeneratorTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func generatesOneSpecPerTrainingDay() throws {
        let plan = makePlan(days: makeSevenDays(training: [1, 3, 5], blocks: [makeBlock(items: [makeItem()])]))
        let specs = WeeklyScheduleGenerator.makeSpecs(
            plan: plan,
            settings: ReminderSettings(leadMinutes: 5),
            now: now
        )

        #expect(specs.count == 3)
        let first = try #require(specs.first)
        #expect(first.weekday == .monday)
        #expect(first.triggerTime == TimeOfDay(hour: 20, minute: 25))
        #expect(first.workoutTime == TimeOfDay(hour: 20, minute: 30))
    }

    @Test func fallsBackToDefaultTimeWhenMissing() {
        var days = makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem()])])
        days[0].scheduledTime = nil
        let plan = makePlan(days: days)
        let specs = WeeklyScheduleGenerator.makeSpecs(
            plan: plan,
            settings: ReminderSettings(leadMinutes: 5, defaultTime: TimeOfDay(hour: 19, minute: 0)),
            now: now
        )

        #expect(specs.first?.workoutTime == TimeOfDay(hour: 19, minute: 0))
        #expect(specs.first?.triggerTime == TimeOfDay(hour: 18, minute: 55))
    }

    @Test func restDaysProduceNoSpecs() {
        let plan = makePlan(days: makeSevenDays(training: [], blocks: []))
        let specs = WeeklyScheduleGenerator.makeSpecs(plan: plan, settings: ReminderSettings(), now: now)
        #expect(specs.isEmpty)
    }

    @Test func leadTimeAcrossMidnightMovesWeekdayBack() {
        var days = makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem()])])
        days[0].scheduledTime = TimeOfDay(hour: 0, minute: 5)
        let plan = makePlan(days: days)
        let specs = WeeklyScheduleGenerator.makeSpecs(
            plan: plan,
            settings: ReminderSettings(leadMinutes: 30),
            now: now
        )

        #expect(specs.first?.triggerTime == TimeOfDay(hour: 23, minute: 35))
        #expect(specs.first?.weekday == .sunday)
    }

    @Test func disabledSettingsProduceNothing() {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem()])]))
        var settings = ReminderSettings()
        settings.enabled = false
        #expect(WeeklyScheduleGenerator.makeSpecs(plan: plan, settings: settings, now: now).isEmpty)
    }
}
