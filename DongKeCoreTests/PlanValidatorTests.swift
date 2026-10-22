import Testing
@testable import DongKeCore

@Suite("PlanValidator")
struct PlanValidatorTests {
    @Test func validPlanHasNoIssues() {
        let plan = makePlan(days: makeSevenDays(training: [1, 3, 5], blocks: [makeBlock(items: [makeItem()])]))
        #expect(PlanValidator.validate(plan).isEmpty)
    }

    @Test func rejectsZeroSets() {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem(sets: 0)])]))
        #expect(PlanValidator.validate(plan).contains { $0.path.contains("sets") })
    }

    @Test func rejectsTooManySets() {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem(sets: 21)])]))
        #expect(PlanValidator.validate(plan).contains { $0.path.contains("sets") })
    }

    @Test func rejectsNegativeRest() {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem(rest: -1)])]))
        #expect(PlanValidator.validate(plan).contains { $0.path.contains("restSec") })
    }

    @Test func rejectsRestOverSixHundred() {
        let plan = makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem(rest: 601)])]))
        #expect(PlanValidator.validate(plan).contains { $0.path.contains("restSec") })
    }

    @Test func rejectsWrongDayCount() {
        let plan = makePlan(days: [makeDay(index: 1, blocks: [makeBlock(items: [makeItem()])])])
        #expect(PlanValidator.validate(plan).contains { $0.path == "days" })
    }

    @Test func rejectsDaysPerWeekMismatch() {
        var plan = makePlan(days: makeSevenDays(training: [1, 3], blocks: [makeBlock(items: [makeItem()])]))
        plan.meta.daysPerWeek = 5
        #expect(PlanValidator.validate(plan).contains { $0.path == "meta.daysPerWeek" })
    }

    @Test func rejectsWeekdayIndexMismatch() {
        var days = makeSevenDays(training: [1], blocks: [makeBlock(items: [makeItem()])])
        days[0].weekday = .tuesday
        let plan = makePlan(days: days)
        #expect(PlanValidator.validate(plan).contains { $0.path.contains("weekday") })
    }
}
