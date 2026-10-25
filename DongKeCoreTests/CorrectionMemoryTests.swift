import Foundation
import Testing
@testable import DongKeCore

private func item(
    catalog: String = "squat",
    sets: Int = 3,
    value: Int = 12,
    type: SetTargetType = .reps
) -> ExercisePrescription {
    ExercisePrescription(
        itemId: "i1",
        catalogId: catalog,
        name: ExerciseLibrary.entry(for: catalog)?.name ?? catalog,
        sets: sets,
        target: SetTarget(type: type, value: value, perSide: false),
        restSec: 90
    )
}

private func plan(_ items: [ExercisePrescription]) -> WorkoutPlan {
    makePlan(days: makeSevenDays(training: [1], blocks: [makeBlock(items: items)]))
}

@Test("改一次只是记下来，还不能用它")
func firstEditIsNotEnough() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    #expect(memory.settled(for: "squat", field: .sets) == nil)
    #expect(memory.count == 1)
}

@Test("连着两次改成同一个值，才生效")
func twiceSameValueSettles() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    #expect(memory.settled(for: "squat", field: .sets) == 2)
    #expect(memory.tally(for: "squat", field: .sets)?.count == 2)
}

@Test("第二次改成别的值，前一次作废——不能拿旧口径套新想法")
func differentValueResetsCount() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 4)
    #expect(memory.settled(for: "squat", field: .sets) == nil)
    #expect(memory.tally(for: "squat", field: .sets)?.to == 4)
    #expect(memory.tally(for: "squat", field: .sets)?.count == 1)
}

@Test("生效时改组数，不动次数")
func appliesSetsOnly() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    let result = memory.applying(to: plan([item(sets: 3, value: 12)]))
    #expect(result.plan.days[0].blocks[0].items[0].sets == 2)
    #expect(result.plan.days[0].blocks[0].items[0].target.value == 12)
    #expect(result.applied.count == 1)
    #expect(result.applied[0].field == .sets)
}

@Test("生效时改次数，不动组数；秒数动作也认")
func appliesValueOnly() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "plank", field: .value, to: 40)
    memory.record(catalogId: "plank", field: .value, to: 40)
    let result = memory.applying(to: plan([item(catalog: "plank", sets: 3, value: 30, type: .durationSec)]))
    #expect(result.plan.days[0].blocks[0].items[0].target.value == 40)
    #expect(result.plan.days[0].blocks[0].items[0].sets == 3)
    #expect(result.applied[0].unit == " 秒")
}

@Test("解析出来的值本来就是它，什么都不做，也不加说明")
func noOpWhenAlreadyMatches() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    let original = plan([item(sets: 2)])
    let result = memory.applying(to: original)
    #expect(result.applied.isEmpty)
    #expect(result.plan == original)
}

@Test("改动写进「我替你判断了这些」，不静默")
func disclosureGoesIntoAssumptions() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    let draft = ParsedPlanDraft(
        plan: plan([item(sets: 3)]),
        issues: [],
        rawText: "",
        path: .freeText,
        assumptions: ["按 8 周安排"]
    )
    let corrected = memory.applying(to: draft)
    #expect(corrected.assumptions.count == 2)
    #expect(corrected.assumptions[0].contains("组数 3 → 2"))
    #expect(corrected.assumptions[0].contains("连着 2 次"))
    #expect(corrected.assumptions[1] == "按 8 周安排")
}

@Test("同一个动作排了三天，说明只出现一次——别让一条动作吃光六行额度")
func duplicateDisclosureIsCollapsed() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    let item = item(sets: 3)
    let draft = ParsedPlanDraft(
        plan: makePlan(days: makeSevenDays(training: [1, 3, 5], blocks: [makeBlock(items: [item])])),
        issues: [],
        rawText: "",
        path: .freeText
    )
    let corrected = memory.applying(to: draft)
    #expect(corrected.assumptions.count == 1)
    let days = corrected.plan?.days.filter { $0.isRestDay == false } ?? []
    #expect(days.allSatisfy { $0.blocks[0].items[0].sets == 2 })
}

@Test("没识别成库内动作的条目一律不记——记住一个假 id 会污染所有人")
func unknownCatalogIsIgnored() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "我自己的某个动作", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 0)
    #expect(memory.count == 0)
}

@Test("两个动作互不影响，同一动作的两个字段也互不影响")
func keysAreIndependent() {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .value, to: 8)
    #expect(memory.settled(for: "squat", field: .sets) == 2)
    #expect(memory.settled(for: "squat", field: .value) == nil)
    #expect(memory.settled(for: "push_up", field: .sets) == nil)
}

@Test("存进 UserDefaults 再读回来，口径不变")
func codableRoundTrip() throws {
    var memory = CorrectionMemory.empty
    memory.record(catalogId: "squat", field: .sets, to: 2)
    memory.record(catalogId: "squat", field: .sets, to: 2)
    let data = try JSONEncoder().encode(memory)
    let restored = try JSONDecoder().decode(CorrectionMemory.self, from: data)
    #expect(restored == memory)
    #expect(restored.settled(for: "squat", field: .sets) == 2)
}

@Test("改动太多时，说明只列四条，其余折成一句——卡片翻不下就等于没说")
func disclosureIsCapped() {
    var memory = CorrectionMemory.empty
    let ids = ["squat", "push_up", "plank", "calf_raise", "biceps_curl", "glute_bridge"]
    for id in ids {
        memory.record(catalogId: id, field: .sets, to: 2)
        memory.record(catalogId: id, field: .sets, to: 2)
    }
    let items = ids.enumerated().map { index, id in
        ExercisePrescription(
            itemId: "i\(index)",
            catalogId: id,
            name: ExerciseLibrary.entry(for: id)?.name ?? id,
            sets: 3,
            target: SetTarget(type: .reps, value: 12, perSide: false),
            restSec: 60
        )
    }
    let draft = ParsedPlanDraft(
        plan: plan(items),
        issues: [],
        rawText: "",
        path: .freeText
    )
    let corrected = memory.applying(to: draft)
    #expect(corrected.assumptions.count == CorrectionMemory.disclosureLimit + 1)
    #expect(corrected.assumptions.last == "还有 2 处按你上次的改法处理了")
}
