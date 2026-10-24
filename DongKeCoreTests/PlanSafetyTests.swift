import Testing
import Foundation
@testable import DongKeCore

@Suite("不适部位与动作负荷")
struct PlanSafetyTests {
    @Test("从伤病文本认出部位")
    func detectParts() {
        #expect(BodyPartDetector.parts(in: "我最近肩颈不适") == [.shoulderNeck])
        #expect(BodyPartDetector.parts(in: "膝盖疼") == [.knee])
        #expect(BodyPartDetector.parts(in: "腰不好，手腕也有点疼") == [.lowerBack, .wrist])
        #expect(BodyPartDetector.parts(in: "脚踝崴过") == [.ankle])
        #expect(BodyPartDetector.parts(in: "") == [])
        #expect(BodyPartDetector.parts(in: "没有伤病") == [])
    }

    @Test("髋与肘也要认出来，否则确认页承诺的避让落不了地")
    func detectHipAndElbow() {
        #expect(BodyPartDetector.parts(in: "髋关节有点疼") == [.hip])
        #expect(BodyPartDetector.parts(in: "髋不舒服") == [.hip])
        #expect(BodyPartDetector.parts(in: "手肘疼") == [.elbow])
        #expect(BodyPartDetector.parts(in: "背疼") == [.lowerBack])
    }

    @Test("避让词表长词优先，肩颈不会被肩先吃掉")
    func avoidVocabularyPrefersLongerWords() {
        let vocabulary = BodyPart.avoidVocabulary
        let shoulderNeck = vocabulary.firstIndex(of: "肩颈") ?? Int.max
        let shoulder = vocabulary.firstIndex(of: "肩") ?? Int.max
        #expect(shoulderNeck < shoulder)
        #expect(vocabulary.firstIndex(of: "腰背") ?? Int.max < (vocabulary.firstIndex(of: "腰") ?? Int.max))
    }

    @Test("髋不适时深蹲、弓步、罗马尼亚硬拉都被标出来")
    func hipIssues() {
        let plan = makePlan(items: ["squat", "lunge", "dumbbell_rdl", "push_up"])
        let issues = PlanSafetyChecker.check(plan, soreParts: [.hip])
        #expect(issues.map(\.exerciseName) == ["深蹲", "弓步蹲", "哑铃罗马尼亚硬拉"])
    }

    @Test("肘不适时俯卧撑与弯举被标出来")
    func elbowIssues() {
        let plan = makePlan(items: ["push_up", "biceps_curl", "squat"])
        let issues = PlanSafetyChecker.check(plan, soreParts: [.elbow])
        #expect(issues.map(\.exerciseName) == ["俯卧撑", "哑铃弯举"])
    }

    @Test("肩颈不适时标出会压到肩的动作")
    func shoulderIssues() {
        let plan = makePlan(items: ["push_up", "squat"])
        let issues = PlanSafetyChecker.check(plan, soreParts: [.shoulderNeck])
        #expect(issues.count == 1)
        #expect(issues.first?.exerciseName == "俯卧撑")
        #expect(issues.first?.parts == [.shoulderNeck])
        #expect(issues.first?.dayIndex == 1)
    }

    @Test("没有不适就不报问题")
    func noSoreParts() {
        let plan = makePlan(items: ["push_up", "squat"])
        #expect(PlanSafetyChecker.check(plan, soreParts: []).isEmpty)
    }

    @Test("膝不适只标下肢发力动作，不误伤上肢")
    func kneeIssues() {
        let plan = makePlan(items: ["squat", "lunge", "calf_raise", "push_up"])
        let names = PlanSafetyChecker.check(plan, soreParts: [.knee]).map(\.exerciseName)
        #expect(Set(names) == ["深蹲", "弓步蹲"])
    }

    @Test("腰不适时俯身与旋转动作会被标出")
    func lowerBackIssues() {
        let plan = makePlan(items: ["dumbbell_row", "russian_twist", "glute_bridge", "plank"])
        let names = PlanSafetyChecker.check(plan, soreParts: [.lowerBack]).map(\.exerciseName)
        #expect(Set(names) == ["哑铃划船", "俄罗斯转体"])
    }

    @Test("换动作只在目标绕开不适部位时才给，否则回退到降阶")
    func alternativeOnlyWhenTargetClearsSorePart() {
        let knee = PlanSafetyChecker.check(makePlan(items: ["squat"]), soreParts: [.knee])
        #expect(knee.first?.alternativeName == "臀推")
        #expect(knee.first?.regressionName == nil)

        let shoulder = PlanSafetyChecker.check(makePlan(items: ["push_up"]), soreParts: [.shoulderNeck])
        #expect(shoulder.first?.alternativeName == nil)
        #expect(shoulder.first?.regressionName == "跪姿俯卧撑")
    }

    @Test("换动作不能指向自己，也不能指向库外")
    func alternativeIsValid() {
        for entry in ExerciseLibrary.all {
            guard let id = entry.alternativeId else { continue }
            #expect(id != entry.id, "\(entry.id) 的换动作指向自己")
            #expect(ExerciseLibrary.entry(for: id) != nil, "\(entry.id) 的换动作 \(id) 不在库内")
        }
    }

    @Test("膝不适时五个臀部主项一个都不该被挡")
    func gluteWorkSurvivesKneeSoreness() {
        let plan = makePlan(items: [
            "hip_thrust", "single_leg_glute_bridge", "clamshell",
            "side_lying_leg_raise", "glute_bridge"
        ])
        #expect(PlanSafetyChecker.check(plan, soreParts: [.knee]).isEmpty)
    }

    @Test("腰不适时只剩罗马尼亚硬拉被挡，臀部主项仍然可用")
    func gluteWorkSurvivesLowerBackSoreness() {
        let plan = makePlan(items: [
            "dumbbell_rdl", "hip_thrust", "single_leg_glute_bridge",
            "clamshell", "side_lying_leg_raise"
        ])
        let names = PlanSafetyChecker.check(plan, soreParts: [.lowerBack]).map(\.exerciseName)
        #expect(names == ["哑铃罗马尼亚硬拉"])
    }

    @Test("没有库内替代时仍然给出更轻的做法")
    func lighterPlanProvided() {
        let plan = makePlan(items: ["push_up"])
        let issues = PlanSafetyChecker.check(plan, soreParts: [.shoulderNeck])
        #expect(issues.first?.alternativeName == nil)
        #expect(issues.first?.regressionName == "跪姿俯卧撑")
    }

    @Test("降阶名不能和原名一样，否则是废话")
    func lighterNameDiffersFromSelf() {
        for entry in ExerciseLibrary.all {
            let name = entry.regressionName.trimmingCharacters(in: .whitespaces)
            #expect(name.isEmpty == false, "\(entry.name) 没有降阶写法")
            #expect(name != entry.name, "\(entry.name) 的降阶名和原名相同")
        }
    }

    @Test("每个部位都至少有一个力量动作标到，避免标注漏项")
    func everyPartCovered() {
        for part in BodyPart.allCases {
            #expect(
                ExerciseLibrary.all.contains { $0.purposes.contains(.strength) && $0.affectedParts.contains(part) },
                "没有力量动作标到 \(part.chineseName)"
            )
        }
    }

    @Test("肩颈不适时推荐四个康复动作，不是一句「没有」就完了")
    func shoulderNeckReliefs() {
        let reliefs = PlanSafetyChecker.reliefs(for: [.shoulderNeck])
        #expect(Set(reliefs.map(\.id)) == [
            "chin_tuck", "scapular_retraction", "wall_slide", "neck_isometric"
        ])
    }

    @Test("推荐的动作自己不能让同一个部位吃力")
    func reliefsDoNotConflictWithItself() {
        for part in BodyPart.allCases {
            for entry in PlanSafetyChecker.reliefs(for: [part]) {
                #expect(
                    entry.affectedParts.isDisjoint(with: [part]),
                    "\(entry.id) 被推荐给\(part.chineseName)，却又会让这里吃力"
                )
            }
        }
    }

    @Test("没有不适就不推荐")
    func noReliefsWithoutSoreParts() {
        #expect(PlanSafetyChecker.reliefs(for: []).isEmpty)
    }

    @Test("舒缓动作不进生成器的力量池")
    func reliefEntriesStayOutOfGeneratorPool() {
        let pool = Set(PlanCatalog.items.map(\.id))
        for entry in ExerciseLibrary.all where entry.relievedParts.isEmpty == false {
            #expect(pool.contains(entry.id) == false, "\(entry.id) 是舒缓动作，不该被排进主训练")
        }
    }

    @Test("生成器避开的动作，正好是校验器会标出的动作")
    func generatorAndCheckerAgree() {
        for part in BodyPart.allCases {
            let blocked = PlanGenerator.blockedCatalogIds(for: part.chineseName)
            let flagged = Set(
                ExerciseLibrary.all
                    .filter { $0.affectedParts.contains(part) }
                    .map(\.id)
            )
            #expect(blocked == flagged, "\(part.chineseName) 上两套判断不一致")
        }
    }

    @Test("生成器的动作清单只收库内的力量动作")
    func catalogIsStrengthSubset() {
        let libraryIds = Set(ExerciseLibrary.all.map(\.id))
        #expect(Set(PlanCatalog.items.map(\.id)).isSubset(of: libraryIds))
        for item in PlanCatalog.items {
            #expect(
                ExerciseLibrary.entry(for: item.id)?.purposes.contains(.strength) == true,
                "\(item.name) 不是力量动作，不该进生成器"
            )
        }
    }

    private func makePlan(items: [String]) -> WorkoutPlan {
        let prescriptions = items.enumerated().map { offset, id in
            ExercisePrescription(
                itemId: "i\(offset + 1)",
                catalogId: id,
                name: ExerciseLibrary.entry(for: id)?.name ?? id,
                sets: 3,
                target: SetTarget(type: .reps, value: 10, perSide: false),
                restSec: 60
            )
        }
        let block = ExerciseBlock(
            blockId: "b1",
            kind: .main,
            title: "主训练",
            rounds: 1,
            restBetweenItemsSec: 0,
            restBetweenRoundsSec: 0,
            items: prescriptions
        )
        var days = [
            PlanDay(
                dayIndex: 1,
                weekday: .monday,
                isRestDay: false,
                title: "训练",
                scheduledTime: nil,
                estimatedMinutes: 20,
                blocks: [block]
            )
        ]
        for weekday in Weekday.allCases where weekday != .monday {
            days.append(PlanDay(
                dayIndex: weekday.rawValue,
                weekday: weekday,
                isRestDay: true,
                title: "休息",
                scheduledTime: nil,
                estimatedMinutes: 0,
                blocks: []
            ))
        }
        return WorkoutPlan(
            meta: PlanMeta(
                title: "测试计划",
                goal: .generalFitness,
                level: .beginner,
                daysPerWeek: 1,
                sessionMinutes: 20
            ),
            days: days.sorted { $0.dayIndex < $1.dayIndex }
        )
    }
}
