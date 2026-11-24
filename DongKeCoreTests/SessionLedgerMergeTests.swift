import XCTest
import DongKeCore

class SessionLedgerMergeTests: XCTestCase {
    func testMergeWithoutDuplicate() {
        let sessionId = UUID()

        let local = [
            SetLog(sessionId: sessionId, setIndex: 1, reps: 10, unit: .reps, rpe: 7),
            SetLog(sessionId: sessionId, setIndex: 2, reps: 10, unit: .reps, rpe: 7),
        ]

        let remote = [
            SetLog(sessionId: sessionId, setIndex: 3, reps: 12, unit: .reps, rpe: 8),
            SetLog(sessionId: sessionId, setIndex: 4, reps: 12, unit: .reps, rpe: 8),
        ]

        let merged = SessionLedger.merge(local: local, remote: remote)

        XCTAssertEqual(merged.count, 4)
        XCTAssertEqual(merged[0].setIndex, 1)
        XCTAssertEqual(merged[3].setIndex, 4)
    }

    func testMergeDifferentSources() {
        let sessionId = UUID()

        // iPhone 记了组 2
        let local = [
            SetLog(sessionId: sessionId, setIndex: 2, reps: 10, unit: .reps, rpe: 7),
        ]

        // Watch 也记了组 2（不同来源，应该都保留）
        let remote = [
            SetLog(sessionId: sessionId, setIndex: 2, reps: 11, unit: .reps, rpe: 7),
        ]

        let merged = SessionLedger.merge(local: local, remote: remote)

        XCTAssertEqual(merged.count, 2, "不同来源的相同 setIndex 应该都保留")
    }

    func testMergeSorting() {
        let sessionId = UUID()

        let local = [
            SetLog(sessionId: sessionId, setIndex: 3, reps: 10, unit: .reps, rpe: 7),
            SetLog(sessionId: sessionId, setIndex: 1, reps: 10, unit: .reps, rpe: 7),
        ]

        let remote = [
            SetLog(sessionId: sessionId, setIndex: 4, reps: 12, unit: .reps, rpe: 8),
            SetLog(sessionId: sessionId, setIndex: 2, reps: 12, unit: .reps, rpe: 8),
        ]

        let merged = SessionLedger.merge(local: local, remote: remote)

        XCTAssertEqual(merged[0].setIndex, 1)
        XCTAssertEqual(merged[1].setIndex, 2)
        XCTAssertEqual(merged[2].setIndex, 3)
        XCTAssertEqual(merged[3].setIndex, 4)
    }
}
