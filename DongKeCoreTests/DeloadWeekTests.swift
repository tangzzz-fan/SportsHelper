import Foundation
import Testing

@testable import DongKeCore

struct DeloadWeekTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: day))!
    }

    private func item(_ id: String, reps: Int = 12, load: Double = 8) -> ExercisePrescription {
        ExercisePrescription(
            itemId: id,
            catalogId: "squat",
            name: "深蹲",
            sets: 4,
            target: SetTarget(type: .reps, value: reps, perSide: false),
            restSec: 90,
            load: Load(type: .dumbbell, value: load)
        )
    }

    private func plan(startedAt: Date?, items: [ExercisePrescription]) -> WorkoutPlan {
        WorkoutPlan(
            meta: PlanMeta(
                title: "全身",
                goal: .buildMuscle,
                level: .beginner,
                daysPerWeek: 3,
                sessionMinutes: 30,
                notes: ""
            ),
            days: [
                PlanDay(
                    dayIndex: 1,
                    weekday: .monday,
                    isRestDay: false,
                    title: "下肢力量",
                    scheduledTime: nil,
                    estimatedMinutes: 30,
                    blocks: [
                        ExerciseBlock(
                            blockId: "b1",
                            kind: .main,
                            title: "主训练",
                            rounds: 1,
                            restBetweenItemsSec: 0,
                            restBetweenRoundsSec: 0,
                            items: items
                        )
                    ]
                )
            ],
            createdAt: startedAt
        )
    }

    @Test func firstThreeWeeksAreNotDeload() {
        #expect(DeloadWeek.isDeload(weekIndex: 1) == false)
        #expect(DeloadWeek.isDeload(weekIndex: 2) == false)
        #expect(DeloadWeek.isDeload(weekIndex: 3) == false)
    }

    @Test func fourthWeekIsDeload() {
        #expect(DeloadWeek.isDeload(weekIndex: 4))
    }

    @Test func fifthWeekRestores() {
        #expect(DeloadWeek.isDeload(weekIndex: 5) == false)
        #expect(DeloadWeek.isDeload(weekIndex: 8))
    }

    @Test func weekIndexCountsSevenDayBlocks() {
        let start = date(1)
        #expect(DeloadWeek.weekIndex(on: date(1), startedAt: start) == 1)
        #expect(DeloadWeek.weekIndex(on: date(7), startedAt: start) == 1)
        #expect(DeloadWeek.weekIndex(on: date(8), startedAt: start) == 2)
        #expect(DeloadWeek.weekIndex(on: date(22), startedAt: start) == 4)
    }

    @Test func weekIndexSurvivesYearBoundary() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 12, day: 20))!
        let nextYear = calendar.date(from: DateComponents(year: 2027, month: 1, day: 12))!
        // 2026-12-20 之后的第 23 天 → 第 4 周
        #expect(DeloadWeek.weekIndex(on: nextYear, startedAt: start, calendar: calendar) == 4)
    }

    @Test func deloadScalesTargetsInFourthWeek() {
        let started = date(1)
        let base = plan(startedAt: started, items: [item("i1", reps: 12), item("i2", reps: 7)])
        let eased = DeloadWeek.applied(to: base, on: date(22), calendar: calendar)
        let items = eased.days[0].blocks[0].items
        #expect(items[0].target.value == 7)
        #expect(items[1].target.value == 4)
    }

    @Test func deloadKeepsLoadAndSets() {
        let base = plan(startedAt: date(1), items: [item("i1", reps: 12, load: 8)])
        let eased = DeloadWeek.applied(to: base, on: date(22), calendar: calendar)
        let item = eased.days[0].blocks[0].items[0]
        #expect(item.load.value == 8)
        #expect(item.sets == 4)
    }

    @Test func deloadNeverDropsBelowOne() {
        let base = plan(startedAt: date(1), items: [item("i1", reps: 1)])
        let eased = DeloadWeek.applied(to: base, on: date(22), calendar: calendar)
        #expect(eased.days[0].blocks[0].items[0].target.value == 1)
    }

    @Test func disabledFlagLeavesPlanUntouched() {
        let base = plan(startedAt: date(1), items: [item("i1", reps: 12)])
        let eased = DeloadWeek.applied(to: base, on: date(22), enabled: false, calendar: calendar)
        #expect(eased == base)
    }

    @Test func planWithoutStartDateNeverDeloads() {
        let base = plan(startedAt: nil, items: [item("i1", reps: 12)])
        let eased = DeloadWeek.applied(to: base, on: date(22), calendar: calendar)
        #expect(eased == base)
    }

    @Test func noteOnlyAppearsInDeloadWeek() {
        #expect(DeloadWeek.note(enabled: true, weekIndex: 2) == nil)
        #expect(DeloadWeek.note(enabled: false, weekIndex: 4) == nil)
        #expect(DeloadWeek.note(enabled: true, weekIndex: 4)?.contains("减载周") == true)
    }
}
