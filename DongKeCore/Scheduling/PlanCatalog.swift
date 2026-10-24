import Foundation

enum PlanCatalog {
    struct Item {
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

    static let items: [Item] = [
        Item(id: "squat", name: "深蹲", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        Item(id: "lunge", name: "弓步蹲", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        Item(id: "glute_bridge", name: "臀桥", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        Item(id: "wall_sit", name: "靠墙静蹲", equipment: .bodyweight, isStatic: true, isDynamic: false, joint: .lower),
        Item(id: "calf_raise", name: "提踵", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .lower),
        Item(id: "push_up", name: "俯卧撑", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .upper),
        Item(id: "dumbbell_row", name: "哑铃划船", equipment: .dumbbell, isStatic: false, isDynamic: false, joint: .upper),
        Item(id: "shoulder_press", name: "哑铃推举", equipment: .dumbbell, isStatic: false, isDynamic: false, joint: .upper),
        Item(id: "superman", name: "超人式", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .upper),
        Item(id: "bird_dog", name: "鸟狗", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        Item(id: "dead_bug", name: "死虫", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        Item(id: "crunch", name: "卷腹", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        Item(id: "russian_twist", name: "俄罗斯转体", equipment: .bodyweight, isStatic: false, isDynamic: false, joint: .core),
        Item(id: "plank", name: "平板支撑", equipment: .bodyweight, isStatic: true, isDynamic: false, joint: .core),
        Item(id: "side_plank", name: "侧平板", equipment: .bodyweight, isStatic: true, isDynamic: false, joint: .core),
        Item(id: "jumping_jack", name: "开合跳", equipment: .bodyweight, isStatic: false, isDynamic: true, joint: .lower),
        Item(id: "high_knees", name: "高抬腿", equipment: .bodyweight, isStatic: false, isDynamic: true, joint: .lower),
        Item(id: "mountain_climber", name: "登山跑", equipment: .bodyweight, isStatic: false, isDynamic: true, joint: .core)
    ]

    static func blockedIds(for injuries: String) -> Set<String> {
        let parts = BodyPartDetector.parts(in: injuries)
        guard parts.isEmpty == false else { return [] }
        return Set(
            ExerciseLibrary.all
                .filter { $0.affectedParts.isDisjoint(with: parts) == false }
                .map(\.id)
        )
    }
}
