import Foundation
import Testing
@testable import DongKeCore

private func mainItems(_ day: PlanDay) -> [ExercisePrescription] {
    day.blocks.filter { $0.kind == .main }.flatMap(\.items)
}

private func group(of item: ExercisePrescription) -> ExerciseGroup? {
    ExerciseLibrary.entry(for: item.catalogId)?.group
}

private func claimedGroup(of title: String) -> ExerciseGroup? {
    switch title {
    case "下肢力量": .lower
    case "上肢与核心": .upper
    default: nil
    }
}

private func labelledPlans() -> [(String, WorkoutPlan)] {
    let equipmentSets: [(String, [Equipment])] = [
        ("纯自重", [.bodyweight]),
        ("自重+哑铃+卧凳", [.bodyweight, .dumbbell, .bench])
    ]
    let levels: [(String, TrainingLevel)] = [("入门", .beginner), ("进阶", .advanced)]
    return equipmentSets.flatMap { label, equipment in
        levels.flatMap { levelLabel, level in
            [15, 20, 30, 60].flatMap { minutes in
                [2, 3, 5].map { days in
                    let profile = UserProfile(
                        level: level,
                        availableWeekdays: Array(Weekday.allCases.prefix(days)),
                        sessionMinutes: minutes,
                        equipment: equipment
                    )
                    return ("\(label)/\(levelLabel) \(minutes) 分钟 / \(days) 天", PlanGenerator.makePlan(profile: profile))
                }
            }
        }
    }
}

@Suite("日名与内容")
struct PlanDayNamingTests {

    @Test("专项日只排本组动作，不拿另一组凑名额")
    func specialisedDayStaysInItsGroup() {
        for (label, plan) in labelledPlans() {
            for day in plan.days where day.isRestDay == false {
                guard let claimed = claimedGroup(of: day.title) else { continue }
                for item in mainItems(day) {
                    #expect(
                        group(of: item) == claimed,
                        "\(label) 的\(day.title)里排了 \(item.catalogId)"
                    )
                }
            }
        }
    }

    @Test("标题点名的肌群至少占三个名额，凑不出就不该叫这个名字")
    func titleNeedsEnoughSupport() {
        for (label, plan) in labelledPlans() {
            for day in plan.days where day.isRestDay == false {
                guard let claimed = claimedGroup(of: day.title) else { continue }
                let items = mainItems(day)
                let supporting = items.filter { group(of: $0) == claimed }.count
                let expected = min(items.count, PlanGenerator.minSpecializedItems)
                #expect(
                    supporting >= expected,
                    "\(label) 的\(day.title)只有 \(supporting) 个本组动作，共 \(items.count) 个"
                )
            }
        }
    }

    @Test("纯自重的上肢池只有两个动作，那一档不该冒出「上肢与核心」日")
    func bodyweightNeverClaimsUpperDay() {
        let plan = PlanGenerator.makePlan(profile: UserProfile(
            availableWeekdays: [.monday, .wednesday, .friday],
            sessionMinutes: 30,
            equipment: [.bodyweight]
        ))
        let training = plan.days.filter { $0.isRestDay == false }
        #expect(training.contains { $0.title == "上肢与核心" } == false)
        #expect(training.contains { $0.title == "全身循环" })
    }

    @Test("上肢池刚好三个动作时保留上肢日——这条线画在三个，不是五个")
    func upperDayNeedsExactlyThreeOptions() {
        let plan = PlanGenerator.makePlan(profile: UserProfile(
            availableWeekdays: [.monday, .wednesday, .friday],
            sessionMinutes: 30,
            equipment: [.bodyweight, .bench]
        ))
        #expect(plan.days.contains { $0.title == "上肢与核心" && $0.isRestDay == false })
    }

    @Test("有哑铃和卧凳时，上肢日照样存在——降级不是把所有日子拉平成全身")
    func upperDaySurvivesWithEquipment() {
        let plan = PlanGenerator.makePlan(profile: UserProfile(
            availableWeekdays: [.monday, .wednesday, .friday],
            sessionMinutes: 30,
            equipment: [.bodyweight, .dumbbell, .bench]
        ))
        #expect(plan.days.contains { $0.title == "上肢与核心" && $0.isRestDay == false })
    }

    @Test("全身日两组都有活，名额被预算砍掉时也要各留一个")
    func fullBodyDayCoversBothGroups() {
        for (label, plan) in labelledPlans() {
            for day in plan.days where day.isRestDay == false && day.title == "全身循环" {
                let items = mainItems(day)
                let lower = items.filter { group(of: $0) == .lower }.count
                let upper = items.filter { group(of: $0) == .upper }.count
                let floor = min(items.count / 2, PlanGenerator.minSlotsPerGroup)
                #expect(lower >= floor, "\(label) 的\(day.weekday.chineseName)全身日只有 \(lower) 个下肢")
                #expect(upper >= floor, "\(label) 的\(day.weekday.chineseName)全身日只有 \(upper) 个上肢")
            }
        }
    }

    @Test("受影响的膝盖仍不能靠降级混回下肢日")
    func injuriesStillRespected() {
        let plan = PlanGenerator.makePlan(profile: UserProfile(
            availableWeekdays: [.monday, .wednesday, .friday],
            sessionMinutes: 30,
            equipment: [.bodyweight],
            injuries: "膝盖旧伤"
        ))
        let blocked = PlanGenerator.blockedCatalogIds(for: "膝盖旧伤")
        let used = Set(plan.days.flatMap { $0.blocks.flatMap(\.items).map(\.catalogId) })
        #expect(used.isDisjoint(with: blocked))
    }
}
