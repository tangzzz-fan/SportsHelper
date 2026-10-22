import Foundation
import Testing
@testable import DongKeCore

@Suite("休息结束通知")
struct RestNotificationTests {
    private let endsAt = Date(timeIntervalSince1970: 1_700_000_300)

    @Test func identifierUsesRestPrefixAndSession() {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let plan = RestNotificationBuilder.make(
            dayIndex: 2,
            sessionId: sessionId,
            endsAt: endsAt,
            nextTitle: "下一项 · 臀桥"
        )
        #expect(plan.identifier == "dk.rest.11111111-2222-3333-4444-555555555555")
        #expect(plan.identifier.hasPrefix(RestNotificationBuilder.prefix))
    }

    @Test func firesExactlyWhenRestEnds() {
        let plan = RestNotificationBuilder.make(
            dayIndex: 1,
            sessionId: UUID(),
            endsAt: endsAt,
            nextTitle: "组间休息"
        )
        #expect(plan.fireAt == endsAt)
        #expect(plan.title.contains("休息"))
        #expect(plan.body.contains("组间休息"))
    }

    @Test func carriesDayIndexForDeepLink() {
        let plan = RestNotificationBuilder.make(
            dayIndex: 5,
            sessionId: UUID(),
            endsAt: endsAt,
            nextTitle: "组间休息"
        )
        #expect(plan.dayIndex == 5)
    }
}

@Suite("通知负载")
struct ReminderPayloadTests {
    @Test func weekdayRoundTripsThroughUserInfo() {
        for weekday in Weekday.allCases {
            let payload: [AnyHashable: Any] = ReminderPayload.userInfo(weekday: weekday)
            #expect(ReminderPayload.weekday(from: payload) == weekday)
        }
    }

    @Test func missingOrUnknownWeekdayIsNil() {
        let empty: [AnyHashable: Any] = [:]
        #expect(ReminderPayload.weekday(from: empty) == nil)
        let unknown: [AnyHashable: Any] = [ReminderPayload.weekdayKey: 99]
        #expect(ReminderPayload.weekday(from: unknown) == nil)
        let wrongType: [AnyHashable: Any] = [ReminderPayload.weekdayKey: "1"]
        #expect(ReminderPayload.weekday(from: wrongType) == nil)
    }

    @Test func dayIndexRoundTripsThroughUserInfo() {
        for index in 1...7 {
            let payload: [AnyHashable: Any] = ReminderPayload.userInfo(dayIndex: index)
            #expect(ReminderPayload.dayIndex(from: payload) == index)
        }
        let wrongType: [AnyHashable: Any] = [ReminderPayload.dayIndexKey: "3"]
        #expect(ReminderPayload.dayIndex(from: wrongType) == nil)
    }
}
