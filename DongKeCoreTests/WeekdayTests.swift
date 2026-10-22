import Testing
@testable import DongKeCore

@Suite("Weekday")
struct WeekdayTests {
    @Test func mondayMapsToSystemWeekdayTwo() {
        #expect(Weekday.monday.systemWeekday == 2)
    }

    @Test func sundayMapsToSystemWeekdayOne() {
        #expect(Weekday.sunday.systemWeekday == 1)
    }

    @Test func saturdayMapsToSystemWeekdaySeven() {
        #expect(Weekday.saturday.systemWeekday == 7)
    }

    @Test func initFromSystemWeekday() {
        #expect(Weekday(systemWeekday: 1) == .sunday)
        #expect(Weekday(systemWeekday: 2) == .monday)
        #expect(Weekday(systemWeekday: 7) == .saturday)
    }

    @Test func invalidSystemWeekdayReturnsNil() {
        #expect(Weekday(systemWeekday: 0) == nil)
        #expect(Weekday(systemWeekday: 8) == nil)
    }
}
