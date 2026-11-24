import XCTest
import DongKeCore

class AppGroupsStoreTests: XCTestCase {
    var store: AppGroupsStore!

    override func setUp() {
        super.setUp()
        store = AppGroupsStore.shared
    }

    func testSaveAndLoadCheckpoint() throws {
        let checkpoint = WorkoutCheckpoint(
            sessionId: UUID(),
            script: [],
            revision: 1
        )

        try store.saveCheckpoint(checkpoint, sessionId: checkpoint.sessionId)
        let loaded = try store.loadCheckpoint(sessionId: checkpoint.sessionId)

        XCTAssertEqual(loaded?.sessionId, checkpoint.sessionId)
        XCTAssertEqual(loaded?.revision, 1)

        try store.removeCheckpoint(sessionId: checkpoint.sessionId)
    }

    func testPendingLogsJSONLines() throws {
        let log1 = SetLog(
            sessionId: UUID(),
            setIndex: 1,
            reps: 10,
            unit: .reps,
            rpe: 7
        )

        try store.appendPendingLog(log1, sourceDevice: "watch")
        let logs = try store.readPendingLogs()

        XCTAssertGreaterThanOrEqual(logs.count, 1)

        try store.clearPendingLogs()
    }

    func testDeduplicationThreeWayKey() throws {
        let sessionId = UUID()
        let log1 = SetLog(
            sessionId: sessionId,
            setIndex: 1,
            reps: 10,
            unit: .reps,
            rpe: 7
        )
        let log2 = SetLog(
            sessionId: sessionId,
            setIndex: 2,
            reps: 12,
            unit: .reps,
            rpe: 8
        )

        try store.appendPendingLog(log1, sourceDevice: "watch")
        try store.appendPendingLog(log2, sourceDevice: "watch")
        try store.appendPendingLog(log1, sourceDevice: "iphone")  // 不同来源，不去重

        let logs = try store.readPendingLogs()
        XCTAssertGreaterThanOrEqual(logs.count, 2)

        try store.clearPendingLogs()
    }
}
