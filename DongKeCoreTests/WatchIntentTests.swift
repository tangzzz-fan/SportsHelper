import Foundation
import Testing
@testable import DongKeCore

@Suite("手表意图：载荷与回执")
struct WatchIntentTests {
    private func checkpoint() -> WorkoutCheckpoint {
        WorkoutCheckpoint(
            sessionId: UUID(),
            dayIndex: 3,
            stepIndex: 1,
            totalSteps: 5,
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    @Test("开始意图带上通知里那一天")
    func startCarriesDayIndex() {
        let intent = WatchIntent(kind: .start, dayIndex: 5, planRevision: 3)
        #expect(intent.sessionIntent == .watchStart(dayIndex: 5))
    }

    @Test("点了正文而没有通知时，开始意图不带日期")
    func startWithoutDayIsAllowed() {
        let intent = WatchIntent(kind: .start, planRevision: 3)
        #expect(intent.sessionIntent == .watchStart(dayIndex: nil))
    }

    @Test("重新开始必须同时有 dayIndex 和 sessionId，缺一个就不猜")
    func restartNeedsBothFields() {
        let id = UUID()
        #expect(
            WatchIntent(kind: .restart, dayIndex: 5, sessionId: id, planRevision: 3).sessionIntent
                == .watchRestart(dayIndex: 5, sessionId: id)
        )
        #expect(WatchIntent(kind: .restart, dayIndex: 5, planRevision: 3).sessionIntent == nil)
        #expect(WatchIntent(kind: .restart, sessionId: id, planRevision: 3).sessionIntent == nil)
    }

    @Test("五分钟之前的意图不再执行")
    func expiresAfterFiveMinutes() {
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        let intent = WatchIntent(kind: .start, dayIndex: 3, planRevision: 1, createdAt: created)
        #expect(intent.isExpired(now: created.addingTimeInterval(299)) == false)
        #expect(intent.isExpired(now: created.addingTimeInterval(301)) == true)
    }

    @Test("回执只描述做了什么，不带会话内容")
    func ackMirrorsLaunch() {
        let id = UUID()
        #expect(WatchIntentAck(.open(id)).outcome == .opened)
        #expect(WatchIntentAck(.resume(checkpoint())).outcome == .resumed)
        #expect(WatchIntentAck(.create(dayIndex: 3, origin: .watch)).outcome == .created)
        #expect(
            WatchIntentAck(.abandonAndCreate(abandon: id, dayIndex: 3, origin: .watch)).outcome
                == .restarted
        )
        let blocked = WatchIntentAck(.blocked(.staleRestart))
        #expect(blocked.outcome == .blocked)
        #expect(blocked.block == .staleRestart)
    }

    @Test("载荷与回执都能过 JSON")
    func codableRoundTrip() throws {
        let intent = WatchIntent(kind: .restart, dayIndex: 3, sessionId: UUID(), planRevision: 7)
        let decoded = try JSONDecoder().decode(WatchIntent.self, from: JSONEncoder().encode(intent))
        #expect(decoded == intent)

        let ack = WatchIntentAck(outcome: .blocked, block: .unknownDay)
        let roundTrip = try JSONDecoder().decode(WatchIntentAck.self, from: JSONEncoder().encode(ack))
        #expect(roundTrip == ack)
    }
}
