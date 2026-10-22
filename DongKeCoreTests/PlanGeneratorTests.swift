import Testing
import Foundation
@testable import DongKeCore

@Suite("PlanGenerator")
struct PlanGeneratorTests {

    private func profile(
        goal: PlanGoal = .generalFitness,
        level: TrainingLevel = .beginner,
        weekdays: [Weekday] = [.monday, .wednesday, .friday],
        minutes: Int = 30,
        equipment: [Equipment] = [.bodyweight],
        injuries: String = ""
    ) -> UserProfile {
        UserProfile(
            goal: goal,
            level: level,
            availableWeekdays: weekdays,
            sessionMinutes: minutes,
            equipment: equipment,
            injuries: injuries
        )
    }

    @Test("a generated plan always passes the validator")
    func passesValidator() {
        for goal in PlanGoal.allCases {
            for level in TrainingLevel.allCases {
                let plan = PlanGenerator.makePlan(profile: profile(goal: goal, level: level))
                #expect(PlanValidator.validate(plan).isEmpty)
            }
        }
    }

    @Test("every generated plan has seven days with matching weekday and index")
    func sevenDaysAligned() {
        let plan = PlanGenerator.makePlan(profile: profile())
        #expect(plan.days.count == 7)
        for (offset, day) in plan.days.enumerated() {
            #expect(day.dayIndex == offset + 1)
            #expect(day.weekday.rawValue == day.dayIndex)
        }
    }

    @Test("training days equal the available weekdays")
    func trainingDaysMatchProfile() {
        let weekdays: [Weekday] = [.tuesday, .thursday]
        let plan = PlanGenerator.makePlan(profile: profile(weekdays: weekdays))
        let training = plan.days.filter { !$0.isRestDay }
        #expect(training.count == 2)
        #expect(Set(training.map(\.weekday)) == Set(weekdays))
        #expect(plan.meta.daysPerWeek == 2)
    }

    @Test("only catalog ids from the frozen whitelist are used")
    func onlyWhitelistedIds() {
        let whitelist: Set<String> = [
            "squat", "push_up", "plank", "lunge", "glute_bridge", "dumbbell_row",
            "shoulder_press", "jumping_jack", "dead_bug", "wall_sit", "side_plank",
            "calf_raise", "superman", "crunch", "mountain_climber", "high_knees",
            "bird_dog", "russian_twist"
        ]
        let plan = PlanGenerator.makePlan(profile: profile(
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            minutes: 60,
            equipment: [.bodyweight, .dumbbell]
        ))
        for day in plan.days {
            for block in day.blocks {
                for item in block.items {
                    #expect(whitelist.contains(item.catalogId), "unexpected id \(item.catalogId)")
                }
            }
        }
    }

    @Test("knee injury removes squat, lunge and wall sit")
    func kneeInjuryAvoids() {
        let blocked = PlanGenerator.blockedCatalogIds(for: "膝盖旧伤")
        #expect(blocked.contains("squat"))
        #expect(blocked.contains("lunge"))
        #expect(blocked.contains("wall_sit"))

        let plan = PlanGenerator.makePlan(profile: profile(
            weekdays: Array(Weekday.allCases),
            minutes: 60,
            equipment: [.bodyweight, .dumbbell],
            injuries: "膝盖旧伤，蹲久了疼"
        ))
        let used = Set(plan.days.flatMap { $0.blocks.flatMap { $0.items.map(\.catalogId) } })
        #expect(used.isDisjoint(with: blocked))
    }

    @Test("dumbbell exercises are excluded without a dumbbell")
    func equipmentRespected() {
        let plan = PlanGenerator.makePlan(profile: profile(
            weekdays: [.monday, .wednesday],
            minutes: 45,
            equipment: [.bodyweight]
        ))
        let used = Set(plan.days.flatMap { $0.blocks.flatMap { $0.items.map(\.catalogId) } })
        #expect(used.contains("dumbbell_row") == false)
        #expect(used.contains("shoulder_press") == false)
    }

    @Test("a longer session yields more main exercises")
    func sessionLengthChangesVolume() {
        let short = PlanGenerator.makePlan(profile: profile(weekdays: [.monday], minutes: 20))
        let long = PlanGenerator.makePlan(profile: profile(weekdays: [.monday], minutes: 60))
        let shortMain = short.days.flatMap(\.blocks).first(where: { $0.kind == .main })?.items.count ?? 0
        let longMain = long.days.flatMap(\.blocks).first(where: { $0.kind == .main })?.items.count ?? 0
        #expect(longMain > shortMain)
    }

    @Test("level changes the number of sets")
    func levelChangesSets() {
        let beginner = PlanGenerator.makePlan(profile: profile(level: .beginner, weekdays: [.monday]))
        let advanced = PlanGenerator.makePlan(profile: profile(level: .advanced, weekdays: [.monday]))
        let beginnerSets = beginner.days.flatMap(\.blocks).first(where: { $0.kind == .main })?.items.first?.sets ?? 0
        let advancedSets = advanced.days.flatMap(\.blocks).first(where: { $0.kind == .main })?.items.first?.sets ?? 0
        #expect(advancedSets > beginnerSets)
    }

    @Test("goal changes rest length")
    func goalChangesRest() {
        let fat = PlanGenerator.makePlan(profile: profile(goal: .loseFat, weekdays: [.monday]))
        let muscle = PlanGenerator.makePlan(profile: profile(goal: .buildMuscle, weekdays: [.monday]))
        let fatRest = fat.days.flatMap(\.blocks).first(where: { $0.kind == .main })?.items.first?.restSec ?? 0
        let muscleRest = muscle.days.flatMap(\.blocks).first(where: { $0.kind == .main })?.items.first?.restSec ?? 0
        #expect(muscleRest > fatRest)
    }

    @Test("estimated duration lands near the chosen session length")
    func durationMatchesChoice() {
        for minutes in OnboardingDraft.sessionOptions {
            let plan = PlanGenerator.makePlan(profile: profile(
                weekdays: [.monday, .wednesday, .friday],
                minutes: minutes,
                equipment: [.bodyweight, .dumbbell]
            ))
            let training = plan.days.filter { !$0.isRestDay }
            #expect(!training.isEmpty)
            for day in training {
                let ratio = Double(day.estimatedMinutes) / Double(minutes)
                #expect(ratio > 0.6 && ratio < 1.5, "\(minutes) 分钟的计划估成了 \(day.estimatedMinutes)")
            }
        }
    }

    @Test("a heavily restricted profile still yields a valid plan")
    func restrictedProfileStillValid() {
        let plan = PlanGenerator.makePlan(profile: profile(
            weekdays: [.monday],
            minutes: 20,
            equipment: [.bodyweight],
            injuries: "膝盖痛、腰痛、肩痛、手腕痛、脚踝痛"
        ))
        #expect(PlanValidator.validate(plan).isEmpty)
        #expect(plan.days.filter { !$0.isRestDay }.count == 1)
    }
}
