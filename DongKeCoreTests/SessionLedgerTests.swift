import Foundation
import Testing
@testable import DongKeCore

private let ledgerSession = UUID()
private let ledgerStart = Date(timeIntervalSince1970: 1_770_000_000)

private func ledgerLog(
    _ status: SetStatus,
    setIndex: Int,
    origin: SetOrigin = .prescribed
) -> SetLog {
    SetLog(
        sessionId: ledgerSession,
        prescriptionId: "i1",
        catalogId: "squat",
        setIndex: setIndex,
        status: status,
        plannedValue: 12,
        actualValue: status == .skipped ? 0 : (status == .downgraded ? 6 : 12),
        skipReason: status == .skipped ? .tooHard : nil,
        completedAt: ledgerStart.addingTimeInterval(Double(setIndex)),
        origin: origin
    )
}

@Suite("会话账本")
struct SessionLedgerTests {

    @Test("额外组不进完成率分母，也不破坏干净完成")
    func extrasStayOutOfAdherence() {
        var logs = (1...10).map { ledgerLog(.done, setIndex: $0) }
        logs.append(ledgerLog(.done, setIndex: 11, origin: .extra))
        logs.append(ledgerLog(.done, setIndex: 12, origin: .extra))

        let ledger = SessionLedger(prescribedSets: 10, logs: logs)
        #expect(ledger.completedSets == 10)
        #expect(ledger.extraSets == 2)
        #expect(ledger.completionRate == 1)
        #expect(ledger.isComplete)
        #expect(ledger.isClean)
    }

    @Test("跳过一组、加做两组，完成率仍是九成，不能算练过")
    func extrasCannotFillAGap() {
        var logs = (1...9).map { ledgerLog(.done, setIndex: $0) }
        logs.append(ledgerLog(.skipped, setIndex: 10))
        logs.append(ledgerLog(.done, setIndex: 11, origin: .extra))
        logs.append(ledgerLog(.done, setIndex: 12, origin: .extra))

        let ledger = SessionLedger(prescribedSets: 10, logs: logs)
        #expect(ledger.completedSets == 9)
        #expect(ledger.extraSets == 2)
        #expect(abs((ledger.completionRate ?? 0) - 0.9) < 0.0001)
        #expect(ledger.isComplete == false)
        #expect(ledger.isClean == false)
    }

    @Test("降阶进完成率，但不算干净完成")
    func downgradeCountsButIsNotClean() {
        var logs = (1...9).map { ledgerLog(.done, setIndex: $0) }
        logs.append(ledgerLog(.downgraded, setIndex: 10))

        let ledger = SessionLedger(prescribedSets: 10, logs: logs)
        #expect(ledger.completedSets == 10)
        #expect(ledger.downgradedSets == 1)
        #expect(ledger.isComplete)
        #expect(ledger.isClean == false)
    }

    @Test("零计划组数时完成率为 nil，不伪装成 0%")
    func zeroPrescriptionHasNoRate() {
        let ledger = SessionLedger(prescribedSets: 0, logs: [])
        #expect(ledger.completionRate == nil)
        #expect(ledger.isComplete == false)
        #expect(ledger.isClean == false)
    }

    @Test("额外组是跳过时，只记跳过原因，不进额外完成数")
    func skippedExtraIsInvisibleToDose() {
        var logs = [ledgerLog(.done, setIndex: 1)]
        logs.append(ledgerLog(.skipped, setIndex: 2, origin: .extra))

        let ledger = SessionLedger(prescribedSets: 1, logs: logs)
        #expect(ledger.extraSets == 0)
        #expect(ledger.skippedSets == 0)
    }

    @Test("同一组的重复日志只记一次")
    func duplicateLogsCountOnce() {
        let logs = [
            ledgerLog(.done, setIndex: 1),
            ledgerLog(.done, setIndex: 1)
        ]

        let ledger = SessionLedger(prescribedSets: 1, logs: logs)
        #expect(ledger.completedSets == 1)
        #expect(ledger.isClean)
        #expect(SessionLedger.distinct(logs).count == 1)
    }

    @Test("旧 checkpoint 没有 origin 字段时按计划内解码")
    func legacyLogDecodesAsPrescribed() throws {
        let data = try JSONEncoder().encode(ledgerLog(.done, setIndex: 1, origin: .extra))
        let raw = try JSONSerialization.jsonObject(with: data)
        var object = try #require(raw as? [String: Any])
        object.removeValue(forKey: "origin")
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(SetLog.self, from: stripped)
        #expect(decoded.origin == .prescribed)
    }

    @Test("origin 是未知值时按计划内解码，不丢整条断点")
    func unknownOriginFallsBackToPrescribed() throws {
        let data = try JSONEncoder().encode(ledgerLog(.done, setIndex: 1))
        let raw = try JSONSerialization.jsonObject(with: data)
        var object = try #require(raw as? [String: Any])
        object["origin"] = "mystery"
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(SetLog.self, from: stripped)
        #expect(decoded.origin == .prescribed)
    }
}
