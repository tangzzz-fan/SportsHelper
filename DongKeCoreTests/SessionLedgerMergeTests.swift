import Foundation
import Testing
@testable import DongKeCore

private let mergeSession = UUID()
private let mergeStart = Date(timeIntervalSince1970: 1_770_000_000)

private func mergeLog(
    setIndex: Int,
    sessionId: UUID = mergeSession,
    prescriptionId: String? = nil,
    status: SetStatus = .done,
    completedAt: Date = mergeStart
) -> SetLog {
    SetLog(
        sessionId: sessionId,
        prescriptionId: prescriptionId ?? "i\(setIndex)",
        catalogId: "squat",
        setIndex: setIndex,
        status: status,
        plannedValue: 12,
        actualValue: status == .skipped ? 0 : 12,
        completedAt: completedAt
    )
}

private func watchEntry(
    _ log: SetLog,
    at offset: TimeInterval = 0
) -> PendingSetLog {
    PendingSetLog(
        log: log,
        sourceDevice: .watch,
        timestamp: mergeStart.addingTimeInterval(offset)
    )
}

@Suite("会话日志合并")
struct SessionLedgerMergeTests {

    @Test("两端各记不同组，账本合计为全部组")
    func disjointLogsMerge() {
        let local = [mergeLog(setIndex: 1), mergeLog(setIndex: 2)]
        let remote = [watchEntry(mergeLog(setIndex: 3)), watchEntry(mergeLog(setIndex: 4))]

        let ledger = SessionLedger.merge(prescribedSets: 4, local: local, remote: remote)

        #expect(ledger.completedSets == 4)
        #expect(ledger.isComplete)
    }

    @Test("两台设备记了同一组：存储层各留一条，账本只计一次")
    func crossDeviceDuplicateCountsOnce() {
        let local = [mergeLog(setIndex: 1), mergeLog(setIndex: 2)]
        let remote = [watchEntry(mergeLog(setIndex: 2)), watchEntry(mergeLog(setIndex: 3))]

        let merged = SessionLedger.mergedLogs(local: local, remote: remote)
        // 三元组带 sourceDevice，不同设备的两条都保留。
        #expect(merged.count == 4)

        let ledger = SessionLedger.merge(prescribedSets: 3, local: local, remote: remote)
        // 账本按 prescriptionId + setIndex + origin 折叠，组 2 只计一次。
        #expect(ledger.completedSets == 3)
        #expect(ledger.completionRate == 1)
    }

    @Test("同一台设备重复写同一组只留第一条")
    func sameDeviceDuplicateIsDropped() {
        let first = mergeLog(setIndex: 1)
        let rewritten = mergeLog(setIndex: 1)
        let remote = [watchEntry(first), watchEntry(rewritten, at: 5)]

        let merged = SessionLedger.mergedLogs(local: [], remote: remote)

        #expect(merged.count == 1)
        #expect(merged[0].id == first.id)
    }

    @Test("本地重复日志同样只留一条")
    func localDuplicateIsDropped() {
        let first = mergeLog(setIndex: 1)
        let rewritten = mergeLog(setIndex: 1)

        let merged = SessionLedger.mergedLogs(local: [first, rewritten], remote: [])

        #expect(merged.count == 1)
        #expect(merged[0].id == first.id)
    }

    @Test("账本键忽略日志 id 与设备，只认会话/动作/组/来源")
    func ledgerKeyMatchesAcrossDevices() {
        let iPhone = mergeLog(setIndex: 2)
        let watch = mergeLog(setIndex: 2)

        #expect(iPhone.id != watch.id)
        #expect(SetLogKey(iPhone) == SetLogKey(watch))
    }

    @Test("额外组与计划内组是不同的账本键")
    func ledgerKeySeparatesOrigins() {
        let prescribed = mergeLog(setIndex: 2)
        let extra = mergeLog(setIndex: 2) // origin 默认 prescribed
        var extraLog = extra
        extraLog.origin = .extra

        #expect(SetLogKey(prescribed) != SetLogKey(extraLog))
    }

    @Test("两端的跳过与降阶都进同一次账，不会被合并丢掉")
    func mixedStatusesSurviveMerge() {
        let local = [
            mergeLog(setIndex: 1, status: .done),
            mergeLog(setIndex: 2, status: .downgraded),
        ]
        let remote = [
            watchEntry(mergeLog(setIndex: 3, status: .skipped)),
        ]

        let ledger = SessionLedger.merge(prescribedSets: 3, local: local, remote: remote)

        #expect(ledger.doneSets == 1)
        #expect(ledger.downgradedSets == 1)
        #expect(ledger.skippedSets == 1)
        #expect(ledger.completedSets == 2)
    }
}
