import Testing
import Foundation
@testable import DongKeCore

@Suite("SessionRecap")
struct SessionRecapTests {

    private let sessionId = UUID()
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func log(_ status: SetStatus, offset: TimeInterval = 0) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "i1",
            setIndex: 1,
            status: status,
            plannedValue: 12,
            actualValue: status == .downgraded ? 6 : 12,
            skipReason: status == .skipped ? .tooHard : nil,
            completedAt: start.addingTimeInterval(offset)
        )
    }

    @Test("混合状态分别计入三个比率")
    func mixedStatuses() {
        var logs: [SetLog] = []
        logs.append(contentsOf: Array(repeating: log(.done), count: 9))
        logs.append(contentsOf: Array(repeating: log(.downgraded), count: 2))
        logs.append(log(.skipped))

        let recap = SessionRecap(logs: logs, plannedSets: 12, startedAt: start, finishedAt: start.addingTimeInterval(18 * 60))
        #expect(recap.doneSets == 9)
        #expect(recap.downgradedSets == 2)
        #expect(recap.skippedSets == 1)
        #expect(recap.completedSets == 11)
        #expect(abs(recap.completionRate - 11.0 / 12.0) < 0.0001)
        #expect(abs(recap.downgradeRate - 2.0 / 12.0) < 0.0001)
        #expect(abs(recap.skipRate - 1.0 / 12.0) < 0.0001)
        #expect(!recap.isClean)
    }

    @Test("全部干净完成时没有任何降阶或跳过")
    func cleanSession() {
        let logs = Array(repeating: log(.done), count: 8)
        let recap = SessionRecap(logs: logs, plannedSets: 8, startedAt: start, finishedAt: start.addingTimeInterval(600))
        #expect(recap.completionRate == 1)
        #expect(recap.downgradeRate == 0)
        #expect(recap.skipRate == 0)
        #expect(recap.isClean)
    }

    @Test("没开始就结束不会崩，比率全为零")
    func emptySession() {
        let recap = SessionRecap(logs: [], plannedSets: 0, startedAt: start, finishedAt: start)
        #expect(recap.completionRate == 0)
        #expect(recap.downgradeRate == 0)
        #expect(recap.skipRate == 0)
        #expect(recap.durationText == "0 秒")
        #expect(!recap.isClean)
    }

    @Test("结束时间早于开始时间时长的下限为零")
    func negativeDuration() {
        let recap = SessionRecap(logs: [], plannedSets: 4, startedAt: start, finishedAt: start.addingTimeInterval(-90))
        #expect(recap.duration == 0)
        #expect(recap.durationText == "0 秒")
    }

    @Test("时长文案按秒 / 分 / 小时三档")
    func durationFormatting() {
        func text(_ seconds: TimeInterval) -> String {
            SessionRecap(plannedSets: 1, doneSets: 1, downgradedSets: 0, skippedSets: 0, duration: seconds).durationText
        }
        #expect(text(45) == "45 秒")
        #expect(text(60) == "1 分钟")
        #expect(text(90) == "1 分 30 秒")
        #expect(text(18 * 60) == "18 分钟")
        #expect(text(3720) == "1 小时 2 分")
    }

    @Test("百分比四舍五入到整数")
    func percentText() {
        let recap = SessionRecap(plannedSets: 3, doneSets: 2, downgradedSets: 0, skippedSets: 1, duration: 60)
        #expect(recap.percentText(recap.completionRate) == "67%")
        #expect(recap.percentText(recap.skipRate) == "33%")
        #expect(recap.percentText(2.0) == "100%")
        #expect(recap.percentText(-1) == "0%")
    }
}
