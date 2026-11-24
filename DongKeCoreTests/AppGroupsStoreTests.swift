import Foundation
import Testing
@testable import DongKeCore

private let storeSession = UUID()
private let storeStart = Date(timeIntervalSince1970: 1_770_000_000)

private func storeLog(
    setIndex: Int,
    sessionId: UUID = storeSession,
    status: SetStatus = .done,
    completedAt: Date = storeStart
) -> SetLog {
    SetLog(
        sessionId: sessionId,
        prescriptionId: "i\(setIndex)",
        catalogId: "squat",
        setIndex: setIndex,
        status: status,
        plannedValue: 12,
        actualValue: status == .skipped ? 0 : 12,
        completedAt: completedAt
    )
}

private struct TemporaryContainer {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dk-appgroups-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    var store: AppGroupsStore {
        AppGroupsStore(containerURL: url)
    }

    var pendingLogsURL: URL {
        url.appendingPathComponent(AppGroupsStore.workoutsDirectoryName, isDirectory: true)
            .appendingPathComponent(AppGroupsStore.pendingLogsFileName)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

@Suite("App Group 本地存储")
struct AppGroupsStoreTests {

    @Test("checkpoint 保存后能原样读回，删除后返回 nil")
    func checkpointRoundTrip() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store

        let checkpoint = WorkoutCheckpoint(
            sessionId: storeSession,
            dayIndex: 2,
            stepIndex: 3,
            totalSteps: 12,
            startedAt: storeStart,
            updatedAt: storeStart.addingTimeInterval(60),
            restEndsAt: storeStart.addingTimeInterval(90),
            restTotalSeconds: 60,
            logs: [storeLog(setIndex: 1)],
            steps: [.finished],
            revision: 7,
            status: .inProgress
        )

        try store.saveCheckpoint(checkpoint)
        #expect(try store.loadCheckpoint(sessionId: storeSession) == checkpoint)

        try store.removeCheckpoint(sessionId: storeSession)
        #expect(try store.loadCheckpoint(sessionId: storeSession) == nil)
    }

    @Test("没有容器时所有操作抛 containerNotAvailable")
    func unavailableContainerThrows() {
        let store = AppGroupsStore(containerURL: nil)
        #expect(store.isAvailable == false)
        #expect(throws: AppGroupsError.self) {
            try store.saveCheckpoint(
                WorkoutCheckpoint(
                    sessionId: storeSession,
                    dayIndex: 1,
                    stepIndex: 0,
                    totalSteps: 1,
                    startedAt: storeStart,
                    updatedAt: storeStart
                )
            )
        }
        #expect(throws: AppGroupsError.self) {
            _ = try store.readPendingLogs()
        }
    }

    @Test("JSON Lines 追加保留来源设备与顺序")
    func pendingLogsKeepSourceDeviceAndOrder() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store

        let first = storeLog(setIndex: 1)
        let second = storeLog(setIndex: 2)
        try store.appendPendingLog(first, sourceDevice: .watch, at: storeStart)
        try store.appendPendingLog(second, sourceDevice: .iphone, at: storeStart.addingTimeInterval(5))

        let entries = try store.readPendingLogs()
        #expect(entries.count == 2)
        #expect(entries[0].log == first)
        #expect(entries[0].sourceDevice == .watch)
        #expect(entries[0].timestamp == storeStart)
        #expect(entries[1].log == second)
        #expect(entries[1].sourceDevice == .iphone)
    }

    @Test("坏行只跳过自己，不影响后面的好行")
    func malformedLinesAreSkipped() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store

        // 先写一条好行，再在文件尾部掺一行好行和一行坏数据。
        try store.appendPendingLog(storeLog(setIndex: 1), sourceDevice: .watch, at: storeStart)

        let encoder = JSONEncoder()
        var data = try Data(contentsOf: container.pendingLogsURL)
        data.append(try encoder.encode(
            PendingSetLog(log: storeLog(setIndex: 3), sourceDevice: .watch, timestamp: storeStart)
        ))
        data.append(0x0A)
        data.append(Data("{ not json".utf8))
        data.append(0x0A)
        try data.write(to: container.pendingLogsURL)

        // 原文件里的第一条也还在；坏行之后的第三次写也没丢。
        try store.appendPendingLog(storeLog(setIndex: 2), sourceDevice: .watch, at: storeStart)
        let entries = try store.readPendingLogs()
        #expect(entries.map(\.log.setIndex) == [1, 3, 2])
    }

    @Test("按条件删除只留下未同步项")
    func removeMatchingPendingLogs() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store

        try store.appendPendingLog(storeLog(setIndex: 1), sourceDevice: .watch, at: storeStart)
        try store.appendPendingLog(storeLog(setIndex: 2), sourceDevice: .watch, at: storeStart)
        try store.appendPendingLog(storeLog(setIndex: 3), sourceDevice: .watch, at: storeStart)

        try store.removePendingLogs { $0.log.setIndex <= 2 }

        let remaining = try store.readPendingLogs()
        #expect(remaining.map(\.log.setIndex) == [3])
    }

    @Test("整份替换与清空")
    func replaceAndClearPendingLogs() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store

        try store.appendPendingLog(storeLog(setIndex: 1), sourceDevice: .watch, at: storeStart)
        try store.replacePendingLogs([
            PendingSetLog(log: storeLog(setIndex: 9), sourceDevice: .iphone, timestamp: storeStart)
        ])
        #expect(try store.readPendingLogs().map(\.log.setIndex) == [9])

        try store.clearPendingLogs()
        #expect(try store.readPendingLogs().isEmpty)
    }

    @Test("并发追加不丢行、不撕行")
    func concurrentAppendsAreSafe() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store
        let sessionId = UUID()

        DispatchQueue.concurrentPerform(iterations: 20) { index in
            try? store.appendPendingLog(
                storeLog(setIndex: index, sessionId: sessionId),
                sourceDevice: .watch,
                at: storeStart
            )
        }

        let entries = try store.readPendingLogs()
        #expect(entries.count == 20)
        #expect(Set(entries.map(\.log.setIndex)) == Set(0..<20))
    }

    @Test("clearAll 清掉整个 workouts 目录")
    func clearAllRemovesEverything() throws {
        let container = try TemporaryContainer()
        defer { container.remove() }
        let store = container.store

        let checkpoint = WorkoutCheckpoint(
            sessionId: storeSession,
            dayIndex: 1,
            stepIndex: 0,
            totalSteps: 1,
            startedAt: storeStart,
            updatedAt: storeStart
        )
        try store.saveCheckpoint(checkpoint)
        try store.appendPendingLog(storeLog(setIndex: 1), sourceDevice: .watch)

        try store.clearAll()

        #expect(try store.loadCheckpoint(sessionId: storeSession) == nil)
        #expect(try store.readPendingLogs().isEmpty)
    }
}
