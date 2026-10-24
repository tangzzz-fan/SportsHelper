import Foundation

func item(
    _ id: String,
    _ name: String,
    sets: Int,
    value: Int,
    rest: Int,
    perSide: Bool = false,
    type: SetTargetType = .reps
) -> ExercisePrescription {
    ExercisePrescription(
        itemId: id,
        catalogId: id,
        name: name,
        sets: sets,
        target: SetTarget(type: type, value: value, perSide: perSide),
        restSec: rest
    )
}

func block(
    _ id: String,
    kind: BlockKind,
    title: String,
    rounds: Int,
    items: [ExercisePrescription]
) -> ExerciseBlock {
    ExerciseBlock(
        blockId: id,
        kind: kind,
        title: title,
        rounds: rounds,
        restBetweenItemsSec: 90,
        restBetweenRoundsSec: 60,
        items: items
    )
}

func plan(title: String, blocks: [ExerciseBlock]) -> WorkoutPlan {
    let days = (1...7).map { index -> PlanDay in
        let training = index == 1
        return PlanDay(
            dayIndex: index,
            weekday: Weekday(rawValue: index)!,
            isRestDay: !training,
            title: training ? blocks.first?.title ?? "训练" : "休息",
            scheduledTime: training ? TimeOfDay(hour: 20, minute: 30) : nil,
            estimatedMinutes: training ? 30 : 0,
            blocks: training ? blocks : []
        )
    }
    return WorkoutPlan(
        meta: PlanMeta(title: title, goal: .loseFat, level: .beginner, daysPerWeek: 1, sessionMinutes: 30),
        days: days
    )
}

func dump(_ label: String, _ plan: WorkoutPlan) {
    print("")
    print("=== \(label) ===")
    let builder = WorkoutAnnouncementBuilder(plan: plan, dayIndex: 1)
    let flow = WorkoutFlowModel(plan: plan, dayIndex: 1)

    print("计划里的组：")
    for dayBlock in plan.days[1].blocks {
        print("  区块「\(dayBlock.title)」kind=\(dayBlock.kind) rounds=\(dayBlock.rounds)")
        for entry in dayBlock.items {
            print("    \(entry.name) \(entry.sets) 组 × \(entry.target.value)\(entry.target.perSide ? "/侧" : "") · 休息 \(entry.restSec)s")
        }
    }
    print("flow 里实际有 \(flow.plannedSets) 个 set")
    print("播报：")
    print("  \(builder.sessionStart().text)")
    for (index, step) in flow.steps.enumerated() {
        switch step {
        case .set:
            if let announcement = builder.announcement(forStepAt: index) {
                print("  \(announcement.text)")
            }
        case let .roundBreak(seconds):
            print("  [回合休息 \(seconds)s]")
        case let .blockBreak(seconds, _):
            let label = builder.nextActionLabel(afterBlockBreakAt: index) ?? ""
            print("  \(WorkoutAnnouncement.blockBreak(seconds: seconds, nextLabel: label).text)")
        case .finished:
            print("  \(builder.finished(completedSets: flow.plannedSets).text)")
        }
    }
}

func main() {
    let straight = plan(title: "居家减脂 · 4 周", blocks: [
        block("b0", kind: .main, title: "上肢与核心", rounds: 1, items: [
            item("push_up", "俯卧撑", sets: 3, value: 10, rest: 75),
            item("row", "哑铃划船", sets: 3, value: 12, rest: 75, perSide: true),
            item("plank", "平板支撑", sets: 3, value: 40, rest: 60, type: .durationSec)
        ])
    ])

    let circuit = plan(title: "循环燃脂", blocks: [
        block("b0", kind: .circuit, title: "循环", rounds: 3, items: [
            item("squat", "深蹲", sets: 2, value: 12, rest: 30),
            item("row", "哑铃划船", sets: 2, value: 12, rest: 30, perSide: true)
        ])
    ])

    let superset = plan(title: "超级组", blocks: [
        block("b0", kind: .superset, title: "超级组", rounds: 2, items: [
            item("push_up", "俯卧撑", sets: 3, value: 10, rest: 45),
            item("bridge", "臀桥", sets: 3, value: 15, rest: 45)
        ])
    ])

    let multiBlock = plan(title: "居家减脂 · 4 周", blocks: [
        block("b0", kind: .main, title: "热身", rounds: 1, items: [
            item("jack", "开合跳", sets: 1, value: 30, rest: 0, type: .durationSec)
        ]),
        block("b1", kind: .main, title: "主训练", rounds: 1, items: [
            item("push_up", "俯卧撑", sets: 3, value: 10, rest: 75)
        ]),
        block("b2", kind: .main, title: "核心", rounds: 1, items: [
            item("plank", "平板支撑", sets: 2, value: 40, rest: 60, type: .durationSec)
        ])
    ])

    dump("普通主线（当前默认计划形态）", straight)
    dump("循环 circuit：3 轮 × 每动作 2 组", circuit)
    dump("超级组 superset：2 轮 × 每动作 3 组", superset)
    dump("多区块：热身 → 主训练 → 核心", multiBlock)
}

main()
