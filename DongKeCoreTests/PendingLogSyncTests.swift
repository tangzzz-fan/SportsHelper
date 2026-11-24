import Foundation
import Testing
@testable import DongKeCore

private let queueStart = Date(timeIntervalSince1970: 1_770_000_000)
private let queueSession = UUID()

private func queueLog(setIndex: Int, at offset: TimeInterval = 0) -> SetLog {
    SetLog(
        sessionId: queueSession,
        prescriptionId: "i1",
        catalogId: "squat",
        setIndex: setIndex,
        status: .done,
        plannedValue: 12,
        actualValue: 12,
        completedAt: queueStart.addingTimeInterval(offset)
    )
}

private enum SenderError: Error {
    case failed
}

private actor RecordingSender: PendingLogSending {
    private(set) var sent: [PendingSetLog] = []
    private var failAt: Int?

    init(failAt: Int? = nil) {
        self.failAt = failAt
    }

    func send(_ entry: PendingSetLog) async throws {
        if let failAt, sent.count == failAt {
            throw SenderError.failed
        }
        sent.append(entry)
    }

    func sentCount() -> Int {
        sent.count
    }

    func setFailAt(_ index: Int?) {
        failAt = index
    }
}

@Suite("同步退避调度")
struct LogRetrySchedulerTests {

    @Test("初始立刻可尝试")
    func initiallyAllowsAttempt() {
        let scheduler = LogRetryScheduler()
        #expect(scheduler.canAttempt(now: queueStart))
        #expect(scheduler.failureCount == 0)
    }

    @Test("失败后按 5 / 10 / 30 秒退避，之后固定 30 秒")
    func backoffSequence() {
        var scheduler = LogRetryScheduler()
        #expect(scheduler.recordFailure(now: queueStart) == 5)
        #expect(scheduler.recordFailure(now: queueStart) == 10)
        #expect(scheduler.recordFailure(now: queueStart) == 30)
        #expect(scheduler.recordFailure(now: queueStart) == 30)
        #expect(scheduler.failureCount == 4)
    }

    @Test("退避期间不能尝试，到点后恢复")
    func canAttemptAtBoundary() {
        var scheduler = LogRetryScheduler()
        scheduler.recordFailure(now: queueStart)

        #expect(scheduler.canAttempt(now: queueStart.addingTimeInterval(4.99)) == false)
        #expect(scheduler.canAttempt(now: queueStart.addingTimeInterval(5)))
    }

    @Test("成功后清零并清除下一次时间")
    func successResets() {
        var scheduler = LogRetryScheduler()
        scheduler.recordFailure(now: queueStart)
        scheduler.recordSuccess()

        #expect(scheduler.failureCount == 0)
        #expect(scheduler.nextAttemptAt == nil)
        #expect(scheduler.canAttempt(now: queueStart))
        #expect(scheduler.recordFailure(now: queueStart) == 5)
    }
}

@Suite("待发日志队列")
struct PendingLogQueueTests {

    @Test("入队保留来源与时间，待发数递增")
    func enqueueStoresEntries() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)

        let first = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        let second = try await queue.enqueue(
            queueLog(setIndex: 2),
            at: queueStart.addingTimeInterval(1)
        )

        #expect(first == 1)
        #expect(second == 2)
        let entries = try await queue.pending()
        #expect(entries.map(\.log.setIndex) == [1, 2])
        #expect(entries.allSatisfy { $0.sourceDevice == .watch })
        #expect(entries[0].timestamp == queueStart)
    }

    @Test("空队列直接返回 empty")
    func flushEmpty() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender()

        #expect(await queue.flush(using: sender, now: queueStart) == .empty)
    }

    @Test("全部发送成功后清空队列")
    func flushSuccessClears() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender()
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        _ = try await queue.enqueue(queueLog(setIndex: 2), at: queueStart)

        #expect(await queue.flush(using: sender, now: queueStart) == .sent(2))
        #expect(try await queue.pendingCount() == 0)
        #expect(await sender.sentCount() == 2)
    }

    @Test("中途失败只删已成功的，未成功的留到下次")
    func partialFailureKeepsRemaining() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender(failAt: 1)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        _ = try await queue.enqueue(queueLog(setIndex: 2), at: queueStart)
        _ = try await queue.enqueue(queueLog(setIndex: 3), at: queueStart)

        let outcome = await queue.flush(using: sender, now: queueStart)

        #expect(outcome == .failed(sent: 1, remaining: 2, retryAfter: 5))
        #expect(try await queue.pending().map(\.log.setIndex) == [2, 3])
    }

    @Test("退避期内不重复发送")
    func backingOffSkipsSend() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender(failAt: 0)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        _ = await queue.flush(using: sender, now: queueStart)

        let outcome = await queue.flush(
            using: sender,
            now: queueStart.addingTimeInterval(3)
        )

        #expect(outcome == .backingOff(until: queueStart.addingTimeInterval(5)))
        #expect(await sender.sentCount() == 0)
    }

    @Test("到点后重试成功，队列清空")
    func retryAfterBackoffSucceeds() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender(failAt: 0)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        _ = await queue.flush(using: sender, now: queueStart)
        await sender.setFailAt(nil)

        let outcome = await queue.flush(
            using: sender,
            now: queueStart.addingTimeInterval(5)
        )

        #expect(outcome == .sent(1))
        #expect(try await queue.pendingCount() == 0)
    }

    @Test("连续失败按 5 / 10 / 30 退避")
    func repeatedFailuresBackOff() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender(failAt: 0)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)

        let first = await queue.flush(using: sender, now: queueStart)
        #expect(first == .failed(sent: 0, remaining: 1, retryAfter: 5))

        let second = await queue.flush(
            using: sender,
            now: queueStart.addingTimeInterval(5)
        )
        #expect(second == .failed(sent: 0, remaining: 1, retryAfter: 10))

        let third = await queue.flush(
            using: sender,
            now: queueStart.addingTimeInterval(15)
        )
        #expect(third == .failed(sent: 0, remaining: 1, retryAfter: 30))

        let fourth = await queue.flush(
            using: sender,
            now: queueStart.addingTimeInterval(45)
        )
        #expect(fourth == .failed(sent: 0, remaining: 1, retryAfter: 30))
    }

    @Test("成功后重新失败，退避从头算")
    func successThenFailureRestartsBackoff() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender(failAt: 0)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        _ = await queue.flush(using: sender, now: queueStart)

        await sender.setFailAt(nil)
        _ = await queue.flush(using: sender, now: queueStart.addingTimeInterval(5))
        #expect(try await queue.pendingCount() == 0)

        let next = RecordingSender(failAt: 0)
        _ = try await queue.enqueue(queueLog(setIndex: 2), at: queueStart.addingTimeInterval(10))
        let outcome = await queue.flush(
            using: next,
            now: queueStart.addingTimeInterval(10)
        )
        #expect(outcome == .failed(sent: 0, remaining: 1, retryAfter: 5))
    }

    @Test("退避期内新增日志不丢，重试时一起发")
    func enqueueDuringBackoffSurvives() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        let sender = RecordingSender(failAt: 0)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)
        _ = await queue.flush(using: sender, now: queueStart)

        _ = try await queue.enqueue(
            queueLog(setIndex: 2),
            at: queueStart.addingTimeInterval(3)
        )
        await sender.setFailAt(nil)
        let outcome = await queue.flush(
            using: sender,
            now: queueStart.addingTimeInterval(5)
        )

        #expect(outcome == .sent(2))
        #expect(try await queue.pendingCount() == 0)
    }

    @Test("超过 24 小时才提示用户")
    func userAlertAfterOneDay() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)
        _ = try await queue.enqueue(queueLog(setIndex: 1), at: queueStart)

        #expect(try await queue.needsUserAlert(now: queueStart.addingTimeInterval(23 * 3600)) == false)
        #expect(try await queue.needsUserAlert(now: queueStart.addingTimeInterval(24 * 3600)))
    }

    @Test("没有待发日志时不提示")
    func noAlertWhenEmpty() async throws {
        let container = try TemporaryAppGroup()
        defer { container.remove() }
        let queue = PendingLogQueue(store: container.store)

        #expect(try await queue.needsUserAlert(now: queueStart.addingTimeInterval(48 * 3600)) == false)
    }
}
