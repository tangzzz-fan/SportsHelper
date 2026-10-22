import Foundation
@testable import DongKeCore

func makeItem(
    id: String = "i1",
    name: String = "深蹲",
    sets: Int = 3,
    value: Int = 12,
    rest: Int = 90,
    targetType: SetTargetType = .reps,
    perSide: Bool = false
) -> ExercisePrescription {
    ExercisePrescription(
        itemId: id,
        catalogId: "squat",
        name: name,
        sets: sets,
        target: SetTarget(type: targetType, value: value, perSide: perSide),
        restSec: rest
    )
}

func makeBlock(
    id: String = "b1",
    kind: BlockKind = .main,
    rounds: Int = 1,
    items: [ExercisePrescription],
    restBetweenItems: Int = 0,
    restBetweenRounds: Int = 0
) -> ExerciseBlock {
    ExerciseBlock(
        blockId: id,
        kind: kind,
        title: "主训练",
        rounds: rounds,
        restBetweenItemsSec: restBetweenItems,
        restBetweenRoundsSec: restBetweenRounds,
        items: items
    )
}

func makeDay(
    index: Int,
    rest: Bool = false,
    time: String? = "20:30",
    blocks: [ExerciseBlock] = []
) -> PlanDay {
    PlanDay(
        dayIndex: index,
        weekday: Weekday(rawValue: index)!,
        isRestDay: rest,
        title: rest ? "休息" : "训练",
        scheduledTime: time.flatMap(TimeOfDay.init(string:)),
        estimatedMinutes: rest ? 0 : 30,
        blocks: blocks
    )
}

func makeSevenDays(training: [Int], blocks: [ExerciseBlock]) -> [PlanDay] {
    (1...7).map { index in
        makeDay(index: index, rest: !training.contains(index), blocks: training.contains(index) ? blocks : [])
    }
}

func makePlan(days: [PlanDay]) -> WorkoutPlan {
    WorkoutPlan(
        meta: PlanMeta(
            title: "测试计划",
            goal: .loseFat,
            level: .beginner,
            daysPerWeek: days.filter { !$0.isRestDay }.count,
            sessionMinutes: 30
        ),
        days: days
    )
}

func validPlanJSON(schemaVersion: Int = 1, includeRest: Bool = true) -> String {
    let weekdayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

    var item: [String: Any] = [
        "itemId": "i1",
        "catalogId": "squat",
        "name": "深蹲",
        "sets": 4,
        "target": ["type": "reps", "value": 12, "perSide": false],
        "tempo": "",
        "load": ["type": "bodyweight", "value": 0],
        "notes": ""
    ]
    if includeRest {
        item["restSec"] = 90
    }

    let block: [String: Any] = [
        "blockId": "b1",
        "kind": "main",
        "title": "主训练",
        "rounds": 1,
        "restBetweenItemsSec": 0,
        "restBetweenRoundsSec": 0,
        "items": [item],
        "notes": ""
    ]

    let days: [[String: Any]] = (1...7).map { index in
        let isTraining = index == 1
        return [
            "dayIndex": index,
            "weekday": weekdayNames[index - 1],
            "isRestDay": !isTraining,
            "title": isTraining ? "下肢力量" : "休息",
            "scheduledTime": isTraining ? "20:30" : "",
            "estimatedMinutes": isTraining ? 30 : 0,
            "blocks": isTraining ? [block] : [],
            "notes": ""
        ]
    }

    let root: [String: Any] = [
        "schemaVersion": schemaVersion,
        "meta": [
            "title": "居家减脂四周入门",
            "goal": "lose_fat",
            "level": "beginner",
            "daysPerWeek": 1,
            "sessionMinutes": 30,
            "notes": ""
        ],
        "days": days,
        "cautions": ["关节疼痛须停训"]
    ]

    let data = try! JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
}
