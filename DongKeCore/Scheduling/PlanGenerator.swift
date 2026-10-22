import Foundation

public enum PlanGenerator {
    struct CatalogItem {
        var id: String
        var name: String
        var equipment: Equipment
        var isStatic: Bool
        var isDynamic: Bool
        var joint: Joint

        enum Joint {
            case lower, upper, core
        }
    }

    static let catalog: [CatalogItem] = [
        CatalogItem(id: "squat", name: "深蹲", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        CatalogItem(id: "lunge", name: "弓步蹲", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        CatalogItem(id: "glute_bridge", name: "臀桥", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        CatalogItem(id: "wall_sit", name: "靠墙静蹲", equipment: .bodyweight, isStatic: true, isDynamic: false, joint: .lower),
        CatalogItem(id: "calf_raise", name: "提踵", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        CatalogItem(id: "push_up", name: "俯卧撑", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .upper),
        CatalogItem(id: "dumbbell_row", name: "哑铃划船", equipment: .dumbbell, isStatic: false, isDynamic: false, joint: .upper),
        CatalogItem(id: "shoulder_press", name: "哑铃推举", equipment: .dumbbell, isStatic: false, isDynamic: false, joint: .upper),
        CatalogItem(id: "superman", name: "超人式", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .upper),
        CatalogItem(id: "bird_dog", name: "鸟狗", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        CatalogItem(id: "dead_bug", name: "死虫", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        CatalogItem(id: "crunch", name: "卷腹", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        CatalogItem(id: "russian_twist", name: "俄罗斯转体", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        CatalogItem(id: "plank", name: "平板支撑", equipment: .bodyweight, isStatic: true, isDynamic: false, joint: .core),
        CatalogItem(id: "side_plank", name: "侧平板", equipment: .bodyweight, isStatic: true, isDynamic: false, joint: .core),
        CatalogItem(id: "jumping_jack", name: "开合跳", equipment: .bodyweight, isStatic: false, isDynamic: true, joint: .lower),
        CatalogItem(id: "high_knees", name: "高抬腿", equipment: .bodyweight, isStatic: false, isDynamic: true, joint: .lower),
        CatalogItem(id: "mountain_climber", name: "登山跑", equipment: .bodyweight, isStatic: false, isDynamic: true, joint: .core)
    ]

    static let blockedByInjury: [(keywords: [String], ids: Set<String>)] = [
        (["膝", "knee"], ["lunge", "squat", "wall_sit", "jumping_jack"]),
        (["腰", "下背", "lower back", "lowerback"], ["superman", "russian_twist", "dead_bug"]),
        (["肩", "shoulder"], ["push_up", "shoulder_press"]),
        (["腕", "手腕", "wrist"], ["push_up", "plank", "side_plank", "mountain_climber"]),
        (["踝", "脚踝", "ankle"], ["jumping_jack", "high_knees", "calf_raise", "mountain_climber"])
    ]

    public static func blockedCatalogIds(for injuries: String) -> Set<String> {
        let text = injuries.lowercased()
        guard !text.isEmpty else { return [] }
        var blocked: Set<String> = []
        for rule in blockedByInjury where rule.keywords.contains(where: { text.contains($0) }) {
            blocked.formUnion(rule.ids)
        }
        return blocked
    }

    public static func makePlan(profile: UserProfile, now: Date = Date()) -> WorkoutPlan {
        let blocked = blockedCatalogIds(for: profile.injuries)
        let available = catalog.filter { item in
            !blocked.contains(item.id) && profile.equipment.contains(item.equipment)
        }

        let sets = setsForLevel(profile.level)
        let dose = doseForGoal(profile.goal, level: profile.level)
        let rest = restForGoal(profile.goal)
        let trainingWeekdays = Set(profile.availableWeekdays)
        var rotation = 0

        var days: [PlanDay] = []
        for weekday in Weekday.allCases {
            let dayIndex = weekday.rawValue
            guard trainingWeekdays.contains(weekday) else {
                days.append(PlanDay(
                    dayIndex: dayIndex,
                    weekday: weekday,
                    isRestDay: true,
                    title: "休息",
                    scheduledTime: nil,
                    estimatedMinutes: 0,
                    blocks: []
                ))
                continue
            }

            let focus = focusFor(rotation: rotation)
            rotation += 1
            days.append(makeTrainingDay(
                weekday: weekday,
                focus: focus,
                pool: available,
                sets: sets,
                dose: dose,
                rest: rest,
                profile: profile
            ))
        }

        return WorkoutPlan(
            meta: PlanMeta(
                title: "\(profile.goal.chineseName) · \(profile.level.chineseName)",
                goal: profile.goal,
                level: profile.level,
                daysPerWeek: trainingWeekdays.count,
                sessionMinutes: profile.sessionMinutes
            ),
            days: days,
            source: .manual,
            createdAt: now
        )
    }

    private enum Focus {
        case lower, upper, full
    }

    private static func focusFor(rotation: Int) -> Focus {
        switch rotation % 3 {
        case 0: .lower
        case 1: .upper
        default: .full
        }
    }


    private static func setsForLevel(_ level: TrainingLevel) -> Int {
        switch level {
        case .beginner: 2
        case .intermediate: 3
        case .advanced: 4
        }
    }

    private static func restForGoal(_ goal: PlanGoal) -> Int {
        switch goal {
        case .loseFat: 45
        case .buildMuscle: 90
        case .endurance: 40
        case .generalFitness: 60
        case .mobility: 45
        }
    }

    private static func doseForGoal(_ goal: PlanGoal, level: TrainingLevel) -> SetTarget {
        let reps: Int
        switch goal {
        case .loseFat: reps = 15
        case .buildMuscle: reps = 10
        case .endurance: reps = 18
        case .generalFitness: reps = 12
        case .mobility: reps = 12
        }
        let adjusted = level == .beginner ? max(6, reps - 3) : reps
        return SetTarget(type: .reps, value: adjusted, perSide: false)
    }

    private static func staticSeconds(for level: TrainingLevel) -> Int {
        switch level {
        case .beginner: 30
        case .intermediate: 40
        case .advanced: 50
        }
    }

    private static func makeTrainingDay(
        weekday: Weekday,
        focus: Focus,
        pool: [CatalogItem],
        sets: Int,
        dose: SetTarget,
        rest: Int,
        profile: UserProfile
    ) -> PlanDay {
        let warmup = pool.filter(\.isDynamic).first
        let mainCandidates = pool.filter { $0.joint != .core && !$0.isDynamic }
        let coreCandidates = pool.filter { $0.isStatic || $0.joint == .core }

        var main: [CatalogItem] = []
        switch focus {
        case .lower:
            main = mainCandidates.filter { $0.joint == .lower }
        case .upper:
            main = mainCandidates.filter { $0.joint == .upper }
        case .full:
            main = mainCandidates
        }
        main += mainCandidates.filter { item in !main.contains(where: { $0.id == item.id }) }

        let targetSeconds = profile.sessionMinutes * 60
        let workPerSet = dose.type == .durationSec ? dose.value : dose.value * 3
        let warmupCost = (warmup != nil) ? 40 + 20 : 0
        let coreItem = coreCandidates.first
        let coreSets = max(1, sets - 1)
        let coreCost = coreItem == nil ? 0 : coreSets * (staticSeconds(for: profile.level) + 30)
        let budget = max(0, targetSeconds - warmupCost - coreCost)

        var mainSets = sets
        var mainCount = 1
        while mainSets < 6 {
            let perItem = mainSets * (workPerSet + rest)
            let fits = max(1, budget / max(1, perItem))
            mainCount = min(main.count, fits)
            let estimated = mainCount * perItem
            if estimated >= Int(Double(budget) * 0.85) { break }
            mainSets += 1
        }
        mainCount = max(1, min(main.count, mainCount))
        main = Array(main.prefix(mainCount))

        var blocks: [ExerciseBlock] = []

        if let warmup {
            blocks.append(ExerciseBlock(
                blockId: "\(weekday.rawValue)-warmup",
                kind: .warmup,
                title: "热身",
                rounds: 1,
                restBetweenItemsSec: 20,
                restBetweenRoundsSec: 0,
                items: [
                    ExercisePrescription(
                        itemId: "\(weekday.rawValue)-warmup-1",
                        catalogId: warmup.id,
                        name: warmup.name,
                        sets: 1,
                        target: SetTarget(type: .durationSec, value: 40, perSide: false),
                        restSec: 20,
                        tempo: "",
                        load: Load(type: .bodyweight, value: 0)
                    )
                ]
            ))
        }

        blocks.append(ExerciseBlock(
            blockId: "\(weekday.rawValue)-main",
            kind: .main,
            title: title(for: focus),
            rounds: 1,
            restBetweenItemsSec: rest,
            restBetweenRoundsSec: 0,
            items: main.enumerated().map { offset, item in
                ExercisePrescription(
                    itemId: "\(weekday.rawValue)-main-\(offset + 1)",
                    catalogId: item.id,
                    name: item.name,
                    sets: mainSets,
                    target: item.isStatic
                        ? SetTarget(type: .durationSec, value: staticSeconds(for: profile.level), perSide: false)
                        : dose,
                    restSec: rest,
                    tempo: item.isStatic ? "" : "2-0-2",
                    load: Load(type: item.equipment == .dumbbell ? .dumbbell : .bodyweight, value: 0)
                )
            }
        ))

        if let core = coreCandidates.first {
            blocks.append(ExerciseBlock(
                blockId: "\(weekday.rawValue)-core",
                kind: .cooldown,
                title: "核心收尾",
                rounds: 1,
                restBetweenItemsSec: 30,
                restBetweenRoundsSec: 0,
                items: [
                    ExercisePrescription(
                        itemId: "\(weekday.rawValue)-core-1",
                        catalogId: core.id,
                        name: core.name,
                        sets: max(1, sets - 1),
                        target: core.isStatic
                            ? SetTarget(type: .durationSec, value: staticSeconds(for: profile.level), perSide: false)
                            : dose,
                        restSec: 30,
                        tempo: "",
                        load: Load(type: .bodyweight, value: 0)
                    )
                ]
            ))
        }

        let minutes = estimatedMinutes(blocks: blocks)
        return PlanDay(
            dayIndex: weekday.rawValue,
            weekday: weekday,
            isRestDay: false,
            title: title(for: focus),
            scheduledTime: TimeOfDay(
                hour: profile.reminderTime.hour,
                minute: profile.reminderTime.minute
            ),
            estimatedMinutes: minutes,
            blocks: blocks
        )
    }

    private static func title(for focus: Focus) -> String {
        switch focus {
        case .lower: "下肢力量"
        case .upper: "上肢与核心"
        case .full: "全身循环"
        }
    }

    private static func estimatedMinutes(blocks: [ExerciseBlock]) -> Int {
        var seconds = 0
        for block in blocks {
            for item in block.items {
                let workPerSet = item.target.type == .durationSec ? item.target.value : item.target.value * 3
                seconds += item.sets * (workPerSet + item.restSec)
            }
        }
        return max(10, Int((Double(seconds) / 60).rounded()))
    }
}
