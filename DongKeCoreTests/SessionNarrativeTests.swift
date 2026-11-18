import Foundation
import Testing

@testable import DongKeCore

struct SessionNarrativeTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func log(
        _ value: Int,
        load: Load? = nil,
        status: SetStatus = .done,
        setIndex: Int = 1,
        daysLater: Double = 0
    ) -> SetLog {
        SetLog(
            sessionId: UUID(),
            prescriptionId: "p1",
            catalogId: "squat",
            targetType: .reps,
            setIndex: setIndex,
            status: status,
            plannedValue: value,
            actualValue: value,
            actualLoad: load,
            completedAt: day0.addingTimeInterval(daysLater * 86_400)
        )
    }

    private func recap(_ logs: [SetLog], planned: Int) -> SessionRecap {
        SessionRecap(
            logs: logs,
            plannedSets: planned,
            startedAt: day0,
            finishedAt: day0.addingTimeInterval(600)
        )
    }

    @Test func recordLineCarriesWeightAndDelta() {
        let load = Load(type: .dumbbell, value: 10)
        let history = [log(10, load: load, daysLater: -7)]
        let logs = [log(12, load: load)]
        let line = SessionNarrative.headline(
            logs: logs,
            history: history,
            recap: recap(logs, planned: 1)
        )
        #expect(line == "深蹲 10kg 做了 12 个，比上次多 2 个")
    }

    @Test func cleanSessionWithoutRecordStaysSilent() {
        let load = Load(type: .dumbbell, value: 10)
        let history = [log(12, load: load, daysLater: -7)]
        let logs = [log(12, load: load)]
        let line = SessionNarrative.headline(
            logs: logs,
            history: history,
            recap: recap(logs, planned: 1)
        )
        #expect(line == nil)
    }

    @Test func heavyDowngradeGetsOneConcreteHint() {
        let load = Load(type: .dumbbell, value: 10)
        let history = [log(12, load: load, daysLater: -7)]
        let logs = [
            log(12, load: load, setIndex: 1),
            log(12, load: load, setIndex: 2),
            log(6, load: load, status: .downgraded, setIndex: 3),
            log(6, load: load, status: .downgraded, setIndex: 4)
        ]
        let line = SessionNarrative.headline(
            logs: logs,
            history: history,
            recap: recap(logs, planned: 4)
        )
        #expect(line == "深蹲第 3 组只做了 6 个，下次前 2 组各留 1 个余力")
    }

    @Test func allSkippedStaysSilent() {
        let logs = [
            log(12, status: .skipped, setIndex: 1),
            log(12, status: .skipped, setIndex: 2)
        ]
        let line = SessionNarrative.headline(
            logs: logs,
            history: [],
            recap: recap(logs, planned: 2)
        )
        #expect(line == nil)
    }

    @Test func recordBeatsDowngrade() {
        let load = Load(type: .dumbbell, value: 10)
        let history = [log(10, load: load, daysLater: -7)]
        let logs = [
            log(12, load: load, setIndex: 1),
            log(6, load: load, status: .downgraded, setIndex: 2),
            log(6, load: load, status: .downgraded, setIndex: 3)
        ]
        let line = SessionNarrative.headline(
            logs: logs,
            history: history,
            recap: recap(logs, planned: 3)
        )
        #expect(line == "深蹲 10kg 做了 12 个，比上次多 2 个")
    }

    @Test func firstEverSessionStaysSilent() {
        let logs = [log(12)]
        let line = SessionNarrative.headline(
            logs: logs,
            history: [],
            recap: recap(logs, planned: 1)
        )
        #expect(line == nil)
    }
}
