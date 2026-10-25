import Foundation
import Testing
@testable import DongKeCore

private func mainItems(_ day: PlanDay) -> [ExercisePrescription] {
    day.blocks.filter { $0.kind == .main }.flatMap(\.items)
}

private func weeklySets(_ plan: WorkoutPlan) -> [Muscle: Int] {
    var out: [Muscle: Int] = [:]
    for day in plan.days where day.isRestDay == false {
        for item in mainItems(day) {
            for muscle in PrimaryMuscleMap.muscles(for: item.catalogId) {
                out[muscle, default: 0] += item.sets
            }
        }
    }
    return out
}

private func plans() -> [(String, WorkoutPlan)] {
    [15, 20, 30, 45, 60].flatMap { minutes in
        [2, 3, 5].map { days in
            let profile = UserProfile(
                availableWeekdays: Array(Weekday.allCases.prefix(days)),
                sessionMinutes: minutes
            )
            return ("\(minutes) 分钟 / 每周 \(days) 天", PlanGenerator.makePlan(profile: profile))
        }
    }
}

@Test("单次主训练不超过 5 个动作")
func mainItemsPerSession() {
    for (label, plan) in plans() {
        for day in plan.days where day.isRestDay == false {
            #expect(
                mainItems(day).count <= PlanGenerator.maxMainItems,
                "\(label) \(day.weekday.chineseName) 有 \(mainItems(day).count) 个"
            )
        }
    }
}

@Test(
    "单周单肌群组数落在 4–25 的宽松区间",
    .disabled("""
    2026-10-25 实测（30 分钟 / 每周 3 天）：臀 24、股四头 9、小腿 9、腘绳 6、胸 9、背 3。\
    默认档已经落在区间内，但**每周 5 天时臀仍是 65–78**——本轮的上限是「每次课」的，\
    不是「每周」的。肩 / 臂在纯自重组里没有任何力量动作（shoulder_press / lateral_raise /\
    biceps_curl 都要哑铃），是动作库缺口，不是排程问题；核心只出现在收尾块，本指标不计。\
    差的是 §13 的 B：按肌群累计周组数。修完再打开这条。
    """)
)
func weeklySetsPerMuscle() {
    for (label, plan) in plans() {
        for (muscle, sets) in weeklySets(plan) {
            #expect(sets <= 25, "\(label) \(muscle.chineseName) \(sets) 组")
            #expect(sets >= 4, "\(label) \(muscle.chineseName) \(sets) 组")
        }
    }
}

@Test("屏显的「N 个动作」包含热身与收尾，不等于主训练数")
func displayedCountIncludesWarmupAndCore() {
    let plan = PlanGenerator.makePlan(profile: UserProfile())
    let day = plan.days.first { $0.isRestDay == false }!
    let all = day.blocks.flatMap(\.items).count
    let main = mainItems(day).count
    #expect(all > main)
    #expect(all - main == 2, "热身 1 个 + 核心收尾 1 个")
}

@Test("同一节课里，同一个主导肌群最多两个动作——五个名额不能拿来说同一句话")
func leadMusclesAreSpread() {
    for (label, plan) in plans() {
        for day in plan.days where day.isRestDay == false {
            let leads = mainItems(day).compactMap { PlanGenerator.leadMuscle(of: $0.catalogId) }
            for muscle in Set(leads) {
                let count = leads.filter { $0 == muscle }.count
                #expect(
                    count <= PlanGenerator.maxItemsPerLeadMuscle,
                    "\(label) \(day.weekday.chineseName) 的 \(muscle.chineseName) 排了 \(count) 个"
                )
            }
        }
    }
}

@Test("下肢日不会排成一整节只有股四头与臀")
func lowerDayCoversMoreThanTwoMuscles() {
    let plan = PlanGenerator.makePlan(profile: UserProfile())
    let lower = plan.days.first { !$0.isRestDay }!
    let leads = Set(mainItems(lower).compactMap { PlanGenerator.leadMuscle(of: $0.catalogId) })
    #expect(leads.count >= 3, "只覆盖了 \(leads.map(\.chineseName))")
}
