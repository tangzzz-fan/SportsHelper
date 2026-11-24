import Foundation
import Testing
@testable import DongKeCore

private let checkpointSession = UUID()
private let checkpointStart = Date(timeIntervalSince1970: 1_770_000_000)

@Suite("会话快照序列化")
struct WorkoutCheckpointTests {

    @Test("新字段往返完整")
    func newFieldsRoundTrip() throws {
        let checkpoint = WorkoutCheckpoint(
            sessionId: checkpointSession,
            dayIndex: 1,
            stepIndex: 2,
            totalSteps: 8,
            startedAt: checkpointStart,
            updatedAt: checkpointStart.addingTimeInterval(30),
            logs: [],
            steps: [.finished],
            revision: 4,
            status: .inProgress
        )

        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(WorkoutCheckpoint.self, from: data)

        #expect(decoded == checkpoint)
        #expect(decoded.revision == 4)
        #expect(decoded.status == .inProgress)
    }

    @Test("老断点没有 revision / status 时兜默认值，不能整条读不出来")
    func legacyCheckpointDecodesWithDefaults() throws {
        let checkpoint = WorkoutCheckpoint(
            sessionId: checkpointSession,
            dayIndex: 3,
            stepIndex: 1,
            totalSteps: 6,
            startedAt: checkpointStart,
            updatedAt: checkpointStart,
            restEndsAt: nil,
            restTotalSeconds: 45,
            logs: [],
            steps: nil
        )
        let data = try JSONEncoder().encode(checkpoint)
        var object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: "revision")
        object.removeValue(forKey: "status")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WorkoutCheckpoint.self, from: legacyData)

        #expect(decoded.revision == 1)
        #expect(decoded.status == .inProgress)
        #expect(decoded.sessionId == checkpointSession)
        #expect(decoded.restTotalSeconds == 45)
    }

    @Test("计划改版后旧快照不再匹配")
    func revisionMismatchIsDetected() {
        let checkpoint = WorkoutCheckpoint(
            sessionId: checkpointSession,
            dayIndex: 1,
            stepIndex: 0,
            totalSteps: 1,
            startedAt: checkpointStart,
            updatedAt: checkpointStart,
            revision: 2
        )

        #expect(checkpoint.matchesRevision(2))
        #expect(checkpoint.matchesRevision(3) == false)
    }
}
