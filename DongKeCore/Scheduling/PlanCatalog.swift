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

    static let blockedByInjury: [(keywords: [String], ids: Set<String>)] = [
        (["膝", "knee"], ["lunge", "squat", "wall_sit", "jumping_jack"]),
        (["腰", "下背", "lower back", "lowerback"], ["superman", "russian_twist", "dead_bug"]),
        (["肩", "shoulder"], ["push_up", "shoulder_press"]),
        (["腕", "手腕", "wrist"], ["push_up", "plank", "side_plank", "mountain_climber"]),
        (["踝", "脚踝", "ankle"], ["jumping_jack", "high_knees", "calf_raise", "mountain_climber"])
    ]

    static func blockedIds(for injuries: String) -> Set<String> {
        let text = injuries.lowercased()
        guard !text.isEmpty else { return [] }
        var blocked: Set<String> = []
        for rule in blockedByInjury where rule.keywords.contains(where: { text.contains($0) }) {
            blocked.formUnion(rule.ids)
        }
        return blocked
    }
}
