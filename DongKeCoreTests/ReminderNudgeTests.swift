import Foundation
import Testing

@testable import DongKeCore

struct ReminderNudgeTests {
    private func sample(_ weekday: Weekday, reminder: Int, start: Int) -> ReminderSample {
        ReminderSample(weekday: weekday, reminderMinute: reminder, startMinute: start)
    }

    private let eightThirty = 20 * 60 + 30

    @Test func threeLateSessionsMoveTheReminder() throws {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 70),
            sample(.monday, reminder: eightThirty, start: eightThirty + 80),
            sample(.monday, reminder: eightThirty, start: eightThirty + 75)
        ]
        let nudge = try #require(ReminderNudgePlanner.propose(samples: samples))
        #expect(nudge.weekday == .monday)
        #expect(nudge.to.minutesSinceMidnight == eightThirty + 30)
        #expect(nudge.shiftMinutes == 30)
    }

    @Test func twoSessionsAreNotEnough() {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 60),
            sample(.monday, reminder: eightThirty, start: eightThirty + 60)
        ]
        #expect(ReminderNudgePlanner.propose(samples: samples) == nil)
    }

    @Test func mixedDirectionsDoNotTrigger() {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 60),
            sample(.monday, reminder: eightThirty, start: eightThirty + 5),
            sample(.monday, reminder: eightThirty, start: eightThirty + 70)
        ]
        #expect(ReminderNudgePlanner.propose(samples: samples) == nil)
    }

    @Test func slightLatenessIsJustNoise() {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 20),
            sample(.monday, reminder: eightThirty, start: eightThirty + 25),
            sample(.monday, reminder: eightThirty, start: eightThirty + 18)
        ]
        #expect(ReminderNudgePlanner.propose(samples: samples) == nil)
    }

    @Test func smallLatenessOnlyMovesFifteenMinutes() throws {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 45),
            sample(.monday, reminder: eightThirty, start: eightThirty + 50),
            sample(.monday, reminder: eightThirty, start: eightThirty + 46)
        ]
        let nudge = try #require(ReminderNudgePlanner.propose(samples: samples))
        #expect(nudge.shiftMinutes == 15)
    }

    @Test func neverMovesPastWhenYouActuallyStart() throws {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 41),
            sample(.monday, reminder: eightThirty, start: eightThirty + 42),
            sample(.monday, reminder: eightThirty, start: eightThirty + 41)
        ]
        let nudge = try #require(ReminderNudgePlanner.propose(samples: samples))
        // 平均晚 41 分钟，只补一半 → 15；怎么算都不会越过实际开练时间。
        #expect(nudge.shiftMinutes == 15)
        #expect(nudge.shiftMinutes < nudge.averageLateMinutes)
    }

    @Test func onlyTheMostRecentThreeCount() {
        let samples = [
            sample(.monday, reminder: eightThirty, start: eightThirty + 90),
            sample(.monday, reminder: eightThirty, start: eightThirty + 2),
            sample(.monday, reminder: eightThirty, start: eightThirty + 2),
            sample(.monday, reminder: eightThirty, start: eightThirty + 2)
        ]
        // 最近三次都准点，早先那次迟到不该再被翻出来。
        #expect(ReminderNudgePlanner.propose(samples: samples) == nil)
    }

    @Test func rejectionFingerprintIsStableForTheSameTarget() {
        let nudge = ReminderNudge(
            weekday: .monday,
            from: TimeOfDay(hour: 20, minute: 25),
            to: TimeOfDay(hour: 20, minute: 55),
            averageLateMinutes: 55,
            sampleCount: 3
        )
        #expect(nudge.fingerprint == "reminder.1.20:55")
    }
}
