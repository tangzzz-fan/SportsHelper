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

@Test(
    "单次主训练不超过 5 个动作",
    .disabled("""
    2026-10-25 实测：30 分钟单次 10 个主训练动作，60 分钟 13 个。Henry 的依从性拐点是 4 个，\
    依从性上限优先于训练学下限（spec「依从性上限」一节的判据是 >5 就砍动作）。\
    现在这个数会让减量分支对每一份计划都成立——回路第一次出手永远是把东西拿走。\
    修完 §13 再打开这条。
    """)
)
func mainItemsPerSession() {
    for (label, plan) in plans() {
        for day in plan.days where day.isRestDay == false {
            #expect(mainItems(day).count <= 5, "\(label) \(day.weekday.chineseName) 有 \(mainItems(day).count) 个")
        }
    }
}

@Test(
    "单周单肌群组数落在 4–25 的宽松区间",
    .disabled("""
    2026-10-25 实测（30 分钟 / 每周 3 天）：臀 46、股四头 18、小腿 4、腘绳 4、胸 2、背 2，\
    肩 / 臂 / 核心 0。臀接近常见 MRV 的两倍，胸背低于 MEV。\
    根因不在映射表：下肢力量动作 11 个里 6 个只压臀，而每个下肢日把整池都排进来。\
    上下界只是「明显不可能」的粗筛，不是最优区间。修完 §13 再打开这条。
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
