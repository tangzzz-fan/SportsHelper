import Foundation
import Testing
@testable import DongKeCore

@Suite("组记录的余力与多做")
struct SetLogRPETests {
    private let sessionId = UUID()

    private func log(rpe: Int?, actual: Int = 10) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "i1",
            setIndex: 1,
            status: .done,
            plannedValue: 10,
            actualValue: actual,
            rpe: rpe,
            completedAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    @Test("余力可以留空")
    func rpeCanBeNil() {
        #expect(log(rpe: nil).rpe == nil)
    }

    @Test("留空与给了一档不是一回事")
    func nilIsNotAValue() {
        #expect(log(rpe: nil).rpe == nil)
        #expect(log(rpe: 1).rpe == 1)
    }

    @Test("余力往返不丢")
    func rpeRoundTrip() throws {
        let data = try JSONEncoder().encode(log(rpe: 4))
        let decoded = try JSONDecoder().decode(SetLog.self, from: data)
        #expect(decoded.rpe == 4)
    }

    @Test("旧记录没有 rpe 也能解码")
    func legacyRecordDecodes() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","sessionId":"22222222-2222-2222-2222-222222222222","prescriptionId":"i1","setIndex":1,"status":"done","plannedValue":10,"actualValue":10,"completedAt":0}
        """
        let decoded = try JSONDecoder().decode(SetLog.self, from: Data(json.utf8))
        #expect(decoded.rpe == nil)
        #expect(decoded.actualValue == 10)
    }

    @Test("实际完成可以超过目标")
    func actualCanExceedPlanned() {
        let extra = log(rpe: 1, actual: 13)
        #expect(extra.actualValue > extra.plannedValue)
        #expect(extra.actualValue - extra.plannedValue == 3)
    }

    @Test("跳过的一组没有余力也没有实际值")
    func skippedHasNoEffort() {
        let skipped = SetLog(
            sessionId: sessionId,
            prescriptionId: "i1",
            setIndex: 2,
            status: .skipped,
            plannedValue: 10,
            actualValue: 0,
            skipReason: .noTime,
            completedAt: Date(timeIntervalSinceReferenceDate: 0)
        )
        #expect(skipped.rpe == nil)
        #expect(skipped.actualValue == 0)
    }
}
