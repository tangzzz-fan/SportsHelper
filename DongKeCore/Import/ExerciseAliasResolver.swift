import Foundation

public enum ExerciseAliasResolver {
    private static let table: [(alias: String, id: String)] = [
        ("靠墙静蹲", "wall_sit"), ("墙蹲", "wall_sit"), ("wall sit", "wall_sit"), ("wall squat", "wall_sit"),
        ("俄罗斯转体", "russian_twist"), ("转体", "russian_twist"), ("russian twist", "russian_twist"),
        ("侧平板支撑", "side_plank"), ("侧平板", "side_plank"), ("侧支撑", "side_plank"),
        ("side plank", "side_plank"), ("side bridge", "side_plank"),
        ("平板支撑", "plank"), ("平板", "plank"), ("plank", "plank"), ("forearm plank", "plank"),
        ("登山跑", "mountain_climber"), ("登山者", "mountain_climber"), ("爬山式", "mountain_climber"),
        ("mountain climber", "mountain_climber"), ("mountain climbers", "mountain_climber"),
        ("高抬腿", "high_knees"), ("high knees", "high_knees"), ("high knee", "high_knees"),
        ("开合跳", "jumping_jack"), ("jumping jack", "jumping_jack"), ("jumping jacks", "jumping_jack"),
        ("star jump", "jumping_jack"),
        ("俯卧撑", "push_up"), ("伏地挺身", "push_up"), ("push up", "push_up"), ("pushup", "push_up"),
        ("push-up", "push_up"), ("press up", "push_up"),
        ("弓步蹲", "lunge"), ("箭步蹲", "lunge"), ("弓步", "lunge"), ("箭步", "lunge"),
        ("分腿蹲", "lunge"), ("单腿蹲", "lunge"), ("lunge", "lunge"), ("forward lunge", "lunge"),
        ("walking lunge", "lunge"), ("split squat", "lunge"), ("bulgarian split squat", "lunge"),
        ("臀桥", "glute_bridge"), ("桥式", "glute_bridge"), ("glute bridge", "glute_bridge"),
        ("hip bridge", "glute_bridge"),
        ("哑铃划船", "dumbbell_row"), ("划船", "dumbbell_row"), ("row", "dumbbell_row"),
        ("dumbbell row", "dumbbell_row"), ("bent over row", "dumbbell_row"), ("one arm row", "dumbbell_row"),
        ("哑铃推举", "shoulder_press"), ("肩推", "shoulder_press"), ("推举", "shoulder_press"),
        ("shoulder press", "shoulder_press"), ("overhead press", "shoulder_press"), ("military press", "shoulder_press"),
        ("死虫", "dead_bug"), ("dead bug", "dead_bug"), ("deadbug", "dead_bug"),
        ("提踵", "calf_raise"), ("calf raise", "calf_raise"), ("heel raise", "calf_raise"),
        ("鸟狗", "bird_dog"), ("bird dog", "bird_dog"), ("birddog", "bird_dog"),
        ("超人", "superman"), ("superman", "superman"),
        ("卷腹", "crunch"), ("crunch", "crunch"), ("abdominal crunch", "crunch"),
        ("深蹲", "squat"), ("徒手深蹲", "squat"), ("自重深蹲", "squat"), ("squat", "squat"), ("air squat", "squat")
    ]

    public static func catalogId(for rawName: String) -> String? {
        let name = normalize(rawName)
        guard !name.isEmpty else { return nil }

        if let exact = table.first(where: { normalize($0.alias) == name }) {
            return exact.id
        }

        let candidates = table
            .map { (alias: normalize($0.alias), id: $0.id) }
            .filter { pair in
                guard !pair.alias.isEmpty else { return false }
                return name.contains(pair.alias) && pair.alias.count >= minimumLength(pair.alias)
            }
            .sorted { $0.alias.count > $1.alias.count }

        return candidates.first?.id
    }

    public static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let stripped = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF)
        }
        return String(String.UnicodeScalarView(stripped))
    }

    private static func minimumLength(_ alias: String) -> Int {
        alias.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF } ? 2 : 3
    }
}
