import Foundation
import Testing
@testable import DongKeCore

struct PlanRevisionTests {
    private func profile() -> UserProfile {
        UserProfile(
            heightCm: 170,
            weightKg: 65,
            age: 34,
            sex: .female,
            goal: .loseFat,
            level: .beginner,
            availableWeekdays: [.monday, .wednesday, .friday],
            sessionMinutes: 30,
            equipment: [.bodyweight, .dumbbell]
        )
    }

    private func trainingIds(_ plan: WorkoutPlan) -> Set<String> {
        Set(plan.days.filter { !$0.isRestDay }.flatMap { $0.blocks.flatMap { $0.items.map(\.catalogId) } })
    }

    @Test("不改任何参数时，重排结果与首次生成逐条一致")
    func zeroVariationReproducesFirstPlan() {
        let first = PlanGenerator.makePlan(profile: profile())
        let again = PlanGenerator.makePlan(profile: profile(), variation: 0)
        #expect(first.days == again.days)
    }

    @Test("换一版会改掉至少一个训练日的安排，不是原样返回")
    func variationChangesDays() {
        let base = PlanGenerator.makePlan(profile: profile())
        let next = PlanGenerator.makePlan(profile: profile(), variation: 2)
        let baseDays = base.days.map { $0.blocks.flatMap { $0.items.map(\.catalogId) } }
        let nextDays = next.days.map { $0.blocks.flatMap { $0.items.map(\.catalogId) } }
        #expect(baseDays != nextDays, "换版后每天的动作安排完全没变，用户会以为按钮坏了")
    }

    @Test("换版不会引入库外动作，也不会碰休息日")
    func variationStaysInsideCatalog() {
        let base = PlanGenerator.makePlan(profile: profile())
        let next = PlanGenerator.makePlan(profile: profile(), variation: 3)
        let known = Set(ExerciseLibrary.all.map(\.id))
        #expect(trainingIds(next).isSubset(of: known))
        #expect(
            next.days.filter(\.isRestDay).map(\.weekday)
                == base.days.filter(\.isRestDay).map(\.weekday)
        )
    }

    @Test("换版不会把不适部位的禁忌动作排进来")
    func variationRespectsInjuries() {
        var sore = profile()
        sore.injuries = "膝盖疼"
        let next = PlanGenerator.makePlan(profile: sore, variation: 5)
        let blocked = PlanGenerator.blockedCatalogIds(for: sore.injuries)
        #expect(trainingIds(next).isDisjoint(with: blocked))
    }

    @Test("计划来源与版本号能存能读，不再解码成 manual")
    func sourceSurvivesRoundTrip() throws {
        let plan = PlanGenerator.makePlan(profile: profile())
            .markingSource(.ai, revision: 3, now: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: data)
        #expect(decoded.source == .ai)
        #expect(decoded.revision == 3)
        #expect(decoded.isMachineWritten)
    }

    @Test("老存档没有来源字段时回落成手动，不抛错")
    func legacyPlanDecodesWithoutSource() throws {
        let plan = PlanGenerator.makePlan(profile: profile())
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as! [String: Any]
        json.removeValue(forKey: "source")
        json.removeValue(forKey: "revision")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: data)
        #expect(decoded.source == .manual)
        #expect(decoded.revision == 1)
        #expect(decoded.isMachineWritten == false)
    }

    @Test("只有 AI 与导入算机器写的，本地生成与手动不算")
    func machineWrittenClassification() {
        #expect(PlanSource.ai.isMachineWritten)
        #expect(PlanSource.pasteText.isMachineWritten)
        #expect(PlanSource.pasteJSON.isMachineWritten)
        #expect(PlanSource.generated.isMachineWritten == false)
        #expect(PlanSource.manual.isMachineWritten == false)
    }
}
