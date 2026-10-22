import Testing
import Foundation
@testable import DongKeCore

@Suite("Reminder triggers")
struct ReminderTriggerTests {

    private func spec(weekday: Weekday, hour: Int, minute: Int) -> ReminderSpec {
        ReminderSpec(
            id: "dk.plan.test.\(weekday.rawValue)",
            weekday: weekday,
            triggerTime: TimeOfDay(hour: hour, minute: minute),
            workoutTime: TimeOfDay(hour: hour, minute: minute),
            title: "该练了",
            body: "今天 4 个动作"
        )
    }

    @Test("monday maps to calendar weekday 2, not 1")
    func mondayIsTwo() {
        let trigger = ReminderTrigger.from(spec(weekday: .monday, hour: 20, minute: 25))
        #expect(trigger.weekday == 2)
    }

    @Test("sunday maps to calendar weekday 1")
    func sundayIsOne() {
        let trigger = ReminderTrigger.from(spec(weekday: .sunday, hour: 9, minute: 0))
        #expect(trigger.weekday == 1)
    }

    @Test("every weekday keeps hour and minute untouched")
    func hourAndMinutePassThrough() {
        for weekday in Weekday.allCases {
            let trigger = ReminderTrigger.from(spec(weekday: weekday, hour: 6, minute: 45))
            #expect(trigger.hour == 6)
            #expect(trigger.minute == 45)
            #expect((1...7).contains(trigger.weekday))
        }
    }

    @Test("a plan never produces more than seven triggers")
    func cappedAtSeven() {
        var days: [PlanDay] = []
        for (offset, weekday) in Weekday.allCases.enumerated() {
            days.append(PlanDay(
                dayIndex: offset,
                weekday: weekday,
                isRestDay: false,
                title: "训练 \(offset)",
                scheduledTime: TimeOfDay(hour: 20, minute: 30),
                estimatedMinutes: 30,
                blocks: []
            ))
        }
        let plan = WorkoutPlan(
            meta: PlanMeta(title: "每天", goal: .generalFitness, level: .beginner, daysPerWeek: 7, sessionMinutes: 30),
            days: days
        )
        let specs = ReminderPlanBuilder.build(plan: plan, settings: ReminderSettings(), now: Date())
        #expect(specs.count == 7)
        #expect(Set(specs.map(\.weekday)).count == 7)
    }

    @Test("rest days produce no trigger")
    func restDaysSkipped() {
        let plan = WorkoutPlan(
            meta: PlanMeta(title: "单日", goal: .generalFitness, level: .beginner, daysPerWeek: 1, sessionMinutes: 30),
            days: [
                PlanDay(dayIndex: 0, weekday: .monday, isRestDay: true, title: "休息",
                        scheduledTime: nil, estimatedMinutes: 0, blocks: []),
                PlanDay(dayIndex: 1, weekday: .tuesday, isRestDay: false, title: "训练",
                        scheduledTime: TimeOfDay(hour: 20, minute: 0), estimatedMinutes: 30, blocks: [])
            ]
        )
        let specs = ReminderPlanBuilder.build(plan: plan, settings: ReminderSettings(), now: Date())
        #expect(specs.count == 1)
        #expect(specs.first?.weekday == .tuesday)
    }

    @Test("disabled settings produce nothing")
    func disabledProducesNothing() {
        let plan = WorkoutPlan(
            meta: PlanMeta(title: "单日", goal: .generalFitness, level: .beginner, daysPerWeek: 1, sessionMinutes: 30),
            days: [
                PlanDay(dayIndex: 0, weekday: .monday, isRestDay: false, title: "训练",
                        scheduledTime: TimeOfDay(hour: 20, minute: 0), estimatedMinutes: 30, blocks: [])
            ]
        )
        let specs = ReminderPlanBuilder.build(
            plan: plan,
            settings: ReminderSettings(enabled: false),
            now: Date()
        )
        #expect(specs.isEmpty)
    }

    @Test("lead time crossing midnight lands on the previous day")
    func leadCrossesMidnight() {
        let plan = WorkoutPlan(
            meta: PlanMeta(title: "清晨", goal: .generalFitness, level: .beginner, daysPerWeek: 1, sessionMinutes: 30),
            days: [
                PlanDay(dayIndex: 0, weekday: .monday, isRestDay: false, title: "晨练",
                        scheduledTime: TimeOfDay(hour: 0, minute: 20), estimatedMinutes: 30, blocks: [])
            ]
        )
        let specs = ReminderPlanBuilder.build(
            plan: plan,
            settings: ReminderSettings(leadMinutes: 30),
            now: Date()
        )
        #expect(specs.first?.weekday == .sunday)
        #expect(specs.first?.triggerTime.hour == 23)
        #expect(specs.first?.triggerTime.minute == 50)
    }
}
