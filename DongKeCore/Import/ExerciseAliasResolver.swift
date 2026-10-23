import Foundation

public struct ExerciseMatch: Equatable, Sendable {
    public enum Source: String, Sendable {
        case alias
        case memory
    }

    public var catalogId: String
    public var alias: String
    public var modifier: String?
    public var source: Source

    public init(catalogId: String, alias: String, modifier: String? = nil, source: Source = .alias) {
        self.catalogId = catalogId
        self.alias = alias
        self.modifier = modifier
        self.source = source
    }

    public var needsReview: Bool { modifier != nil }
}

public enum ExerciseAliasResolver {
    public static let aliases: [(alias: String, id: String)] = [
        ("靠墙静蹲", "wall_sit"), ("靠墙蹲", "wall_sit"), ("靠墙深蹲", "wall_sit"), ("靠墙马步", "wall_sit"),
        ("静蹲", "wall_sit"), ("墙蹲", "wall_sit"), ("wall sit", "wall_sit"), ("wall squat", "wall_sit"),
        ("俄罗斯转体", "russian_twist"), ("俄罗斯旋体", "russian_twist"), ("转体", "russian_twist"),
        ("旋体", "russian_twist"), ("russian twist", "russian_twist"), ("russian twists", "russian_twist"),
        ("侧平板支撑", "side_plank"), ("侧平板", "side_plank"), ("侧支撑", "side_plank"), ("侧桥", "side_plank"),
        ("侧身平板", "side_plank"), ("side plank", "side_plank"), ("side bridge", "side_plank"),
        ("平板支撑", "plank"), ("平板撑", "plank"), ("平板", "plank"), ("肘撑", "plank"),
        ("平板支掌", "plank"), ("plank", "plank"), ("forearm plank", "plank"),
        ("登山跑", "mountain_climber"), ("登山者", "mountain_climber"), ("登山式", "mountain_climber"),
        ("爬山式", "mountain_climber"), ("爬山跑", "mountain_climber"), ("俯卧提膝", "mountain_climber"),
        ("mountain climber", "mountain_climber"), ("mountain climbers", "mountain_climber"),
        ("高抬腿", "high_knees"), ("high knees", "high_knees"), ("high knee", "high_knees"),
        ("开合跳", "jumping_jack"), ("跳开合", "jumping_jack"), ("星星跳", "jumping_jack"),
        ("jumping jack", "jumping_jack"), ("jumping jacks", "jumping_jack"), ("star jump", "jumping_jack"),
        ("俯卧撑", "push_up"), ("伏地挺身", "push_up"), ("掌上压", "push_up"), ("push up", "push_up"),
        ("pushup", "push_up"), ("push-up", "push_up"), ("press up", "push_up"),
        ("弓步蹲", "lunge"), ("箭步蹲", "lunge"), ("剑步蹲", "lunge"), ("后撤步蹲", "lunge"), ("剪蹲", "lunge"),
        ("弓步", "lunge"), ("箭步", "lunge"), ("分腿蹲", "lunge"), ("单腿蹲", "lunge"),
        ("lunge", "lunge"), ("forward lunge", "lunge"), ("reverse lunge", "lunge"),
        ("walking lunge", "lunge"), ("split squat", "lunge"), ("bulgarian split squat", "lunge"),
        ("臀桥", "glute_bridge"), ("桥式", "glute_bridge"), ("臀举", "glute_bridge"), ("挺髋", "glute_bridge"),
        ("glute bridge", "glute_bridge"), ("hip bridge", "glute_bridge"), ("bridge", "glute_bridge"),
        ("哑铃划船", "dumbbell_row"), ("划船", "dumbbell_row"), ("row", "dumbbell_row"),
        ("dumbbell row", "dumbbell_row"), ("bent over row", "dumbbell_row"), ("one arm row", "dumbbell_row"),
        ("哑铃推举", "shoulder_press"), ("肩推", "shoulder_press"), ("推举", "shoulder_press"),
        ("shoulder press", "shoulder_press"), ("overhead press", "shoulder_press"), ("military press", "shoulder_press"),
        ("死虫", "dead_bug"), ("仰卧伸腿", "dead_bug"), ("dead bug", "dead_bug"), ("deadbug", "dead_bug"),
        ("提踵", "calf_raise"), ("踮脚", "calf_raise"), ("提脚跟", "calf_raise"),
        ("calf raise", "calf_raise"), ("heel raise", "calf_raise"),
        ("鸟狗", "bird_dog"), ("四点支撑", "bird_dog"), ("对侧支撑", "bird_dog"),
        ("bird dog", "bird_dog"), ("birddog", "bird_dog"),
        ("超人", "superman"), ("小燕飞", "superman"), ("燕飞", "superman"), ("superman", "superman"),
        ("卷腹", "crunch"), ("半程仰卧起坐", "crunch"), ("crunch", "crunch"), ("abdominal crunch", "crunch"),
        ("深蹲", "squat"), ("徒手深蹲", "squat"), ("自重深蹲", "squat"), ("空气深蹲", "squat"),
        ("徒手蹲", "squat"), ("下蹲", "squat"), ("蹲起", "squat"),
        ("squat", "squat"), ("air squat", "squat")
    ]

    public static let modifiers: [String] = [
        "保加利亚", "史密斯", "弹力带", "瑞士球", "波速球", "拉力器",
        "杠铃", "哑铃", "壶铃", "绳索", "器械", "负重", "沙袋", "药球",
        "箱式", "相扑", "上斜", "下斜", "窄距", "宽距", "高位", "低位",
        "跳箱", "跳跃", "爆发", "离心", "暂停", "半程", "靠墙",
        "单臂", "单腿", "单手",
        "坐姿", "俯身", "跪姿", "钻石", "反向", "跳", "机"
    ]

    public static func match(for rawName: String, memory: AliasMemory = .empty) -> ExerciseMatch? {
        let name = normalize(rawName)
        guard !name.isEmpty else { return nil }

        if let remembered = memory.catalogId(for: rawName) {
            return ExerciseMatch(
                catalogId: remembered,
                alias: rawName.trimmingCharacters(in: .whitespacesAndNewlines),
                modifier: nil,
                source: .memory
            )
        }

        guard let hit = aliasHit(name) else { return nil }
        return ExerciseMatch(
            catalogId: hit.id,
            alias: hit.alias,
            modifier: uncoveredModifier(in: name, alias: normalize(hit.alias)),
            source: .alias
        )
    }

    public static func catalogId(for rawName: String) -> String? {
        match(for: rawName)?.catalogId
    }

    public static func normalize(_ text: String) -> String {
        let lowered = TextNormalization.simplified(text.lowercased())
        let stripped = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF)
        }
        return String(String.UnicodeScalarView(stripped))
    }

    private static func aliasHit(_ name: String) -> (alias: String, id: String)? {
        if let exact = aliases.first(where: { normalize($0.alias) == name }) {
            return exact
        }

        let candidates = aliases
            .filter { pair in
                let alias = normalize(pair.alias)
                guard !alias.isEmpty else { return false }
                return name.contains(alias) && alias.count >= minimumLength(alias)
            }
            .sorted { normalize($0.alias).count > normalize($1.alias).count }

        return candidates.first
    }

    private static func uncoveredModifier(in name: String, alias: String) -> String? {
        for modifier in modifiers where name.contains(normalize(modifier)) {
            if alias.contains(normalize(modifier)) { continue }
            return modifier
        }
        return nil
    }

    private static func minimumLength(_ alias: String) -> Int {
        alias.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF } ? 2 : 3
    }
}
