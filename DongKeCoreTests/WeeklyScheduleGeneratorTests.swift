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

    @Test func weekdayShiftMovesOnlyTheReminder() throws {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem()])]))
        var settings = ReminderSettings(leadMinutes: 5)
        settings.addShift(30, for: .monday)
        let spec = try #require(WeeklyScheduleGenerator.makeSpecs(plan: plan, settings: settings, now: now).first)
        #expect(spec.triggerTime == TimeOfDay(hour: 20, minute: 55))
        // 计划里的训练时刻不动，只挪提醒。
        #expect(spec.workoutTime == TimeOfDay(hour: 20, minute: 30))
    }

    @Test func legacySettingsWithoutShiftsStillDecode() throws {
        let json = """
        {"enabled": true, "leadMinutes": 10, "soundEnabled": false, "defaultTime": {"hour": 20, "minute": 30}}
        """
        let decoded = try JSONDecoder().decode(ReminderSettings.self, from: Data(json.utf8))
        #expect(decoded.leadMinutes == 10)
        #expect(decoded.shifts.isEmpty)
        #expect(decoded.shift(for: .monday) == 0)
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
        // 提醒挪到周日了，但训的还是周一那节。载荷必须带 dayIndex：
        // Watch 侧只拿到 weekday 的话，反推出来的会是「周日训练」。
        #expect(specs.first?.dayIndex == days[0].dayIndex)
    }

    @Test func specsCarryPlanRevision() {
        var plan = makePlan(days: makeSevenDays(training: [1, 3, 5], blocks: [makeBlock(items: [makeItem()])]))
        plan.revision = 4

        let specs = WeeklyScheduleGenerator.makeSpecs(
            plan: plan,
            settings: ReminderSettings(leadMinutes: 5),
            now: now
        )

        #expect(specs.count == 3)
        #expect(specs.allSatisfy { $0.planRevision == 4 })
    }

    @Test func disabledSettingsProduceNothing() {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem()])]))
        var settings = ReminderSettings()
        settings.enabled = false
        #expect(WeeklyScheduleGenerator.makeSpecs(plan: plan, settings: settings, now: now).isEmpty)
    }
}
