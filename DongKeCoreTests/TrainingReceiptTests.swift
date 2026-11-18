import Foundation
import Testing

@testable import DongKeCore

struct TrainingReceiptTests {
    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let load = Load(type: .dumbbell, value: 8)

    private var plan: WorkoutPlan {
        WorkoutPlan(
            meta: PlanMeta(
                title: "测试",
                goal: .generalFitness,
                level: .beginner,
                daysPerWeek: 1,
                sessionMinutes: 30
            ),
            days: []
        )
    }

    private func log(
        _ value: Int,
        status: SetStatus = .done,
        setIndex: Int = 1,
        reason: SkipReason? = nil,
        daysLater: Double = 0,
        sessionId: UUID = UUID(),
        catalogId: String = "squat"
    ) -> SetLog {
        SetLog(
            sessionId: sessionId,
            prescriptionId: "p1",
            catalogId: catalogId,
            targetType: .reps,
            setIndex: setIndex,
            status: status,
            plannedValue: 12,
            actualValue: value,
            actualLoad: load,
            skipReason: reason,
            completedAt: day0.addingTimeInterval(daysLater * 86_400)
        )
    }

    @Test func emptyLogsSaySo() {
        let receipt = TrainingReceiptBuilder.build(logs: [], plan: plan, now: day0)
        #expect(receipt.body.contains("没有训练记录"))
        #expect(receipt.actions.isEmpty)
    }

    @Test func actionLineCarriesActualAndSkipReason() {
        let session = UUID()
        let logs = [
            log(12, setIndex: 1, sessionId: session),
            log(10, setIndex: 2, sessionId: session),
            log(0, status: .skipped, setIndex: 3, reason: .noEquipment, sessionId: session),
            log(0, status: .skipped, setIndex: 4, reason: .noEquipment, sessionId: session)
        ]
        let receipt = TrainingReceiptBuilder.build(logs: logs, plan: plan, now: day0)
        let line = receipt.actions.first
        #expect(line?.name == "深蹲")
        #expect(line?.actualText == "12/10")
        #expect(line?.skipped == 2)
        #expect(line?.skipReasons == ["没器械"])
        #expect(line?.best == 12)
    }

    @Test func painShowsUpBelowTheTable() {
        let logs = [log(0, status: .skipped, reason: .pain)]
        let receipt = TrainingReceiptBuilder.build(logs: logs, plan: plan, now: day0)
        #expect(receipt.painActions == ["深蹲"])
        #expect(receipt.body.contains("疼痛：深蹲"))
    }

    @Test func bodyHasOneLinePerAction() {
        let logs = [
            log(12, catalogId: "squat"),
            log(40, catalogId: "plank")
        ]
        let receipt = TrainingReceiptBuilder.build(logs: logs, plan: plan, now: day0)
        #expect(receipt.actions.count == 2)
        for action in receipt.actions {
            #expect(receipt.body.contains(action.name))
        }
    }

    @Test func textCarriesSchema() {
        let receipt = TrainingReceiptBuilder.build(logs: [log(12)], plan: plan, now: day0)
        #expect(receipt.text.contains("请据此修订计划"))
        #expect(receipt.text.contains("DongKeWorkoutPlan"))
    }

    @Test func logsOutsideTheWindowAreIgnored() {
        let old = [log(12, daysLater: -60)]
        let receipt = TrainingReceiptBuilder.build(logs: old, plan: plan, now: day0)
        #expect(receipt.actions.isEmpty)
    }
}
