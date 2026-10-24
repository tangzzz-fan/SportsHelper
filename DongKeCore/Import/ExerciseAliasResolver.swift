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
        ("squat", "squat"), ("air squat", "squat"),

        ("手臂绕环", "arm_circle"), ("臂绕环", "arm_circle"), ("绕臂", "arm_circle"), ("arm circle", "arm_circle"),
        ("原地踏步", "march_in_place"), ("踏步", "march_in_place"), ("原地走", "march_in_place"), ("march in place", "march_in_place"),
        ("髋绕环", "hip_circle"), ("转髋", "hip_circle"), ("骨盆绕环", "hip_circle"), ("hip circle", "hip_circle"),
        ("肩胛绕环", "scapular_circle"), ("绕肩", "scapular_circle"), ("肩胛画圈", "scapular_circle"), ("scapular circle", "scapular_circle"),
        ("踝绕环", "ankle_circle"), ("转脚踝", "ankle_circle"), ("脚踝绕环", "ankle_circle"), ("ankle circle", "ankle_circle"),
        ("猫牛式", "cat_cow"), ("猫牛", "cat_cow"), ("猫式牛式", "cat_cow"), ("cat cow", "cat_cow"), ("cat-cow", "cat_cow"),
        ("股四头肌拉伸", "quad_stretch"), ("股四头拉伸", "quad_stretch"), ("大腿前侧拉伸", "quad_stretch"), ("quad stretch", "quad_stretch"),
        ("腘绳肌拉伸", "hamstring_stretch"), ("腿后侧拉伸", "hamstring_stretch"), ("大腿后侧拉伸", "hamstring_stretch"), ("hamstring stretch", "hamstring_stretch"),
        ("髋前侧拉伸", "hip_flexor_stretch"), ("髂腰肌拉伸", "hip_flexor_stretch"), ("跪姿髋屈肌拉伸", "hip_flexor_stretch"), ("hip flexor stretch", "hip_flexor_stretch"),
        ("胸大肌拉伸", "chest_stretch"), ("胸肩拉伸", "chest_stretch"), ("靠墙胸部拉伸", "chest_stretch"), ("chest stretch", "chest_stretch"),
        ("背部拉伸", "back_stretch"), ("抱膝拉伸", "back_stretch"), ("下背拉伸", "back_stretch"), ("back stretch", "back_stretch"),
        ("颈肩拉伸", "neck_stretch"), ("颈部拉伸", "neck_stretch"), ("斜方肌拉伸", "neck_stretch"), ("neck stretch", "neck_stretch"),
        ("小腿拉伸", "calf_stretch"), ("跟腱拉伸", "calf_stretch"), ("腓肠肌拉伸", "calf_stretch"), ("calf stretch", "calf_stretch"),
        ("婴儿式", "child_pose"), ("婴儿式放松", "child_pose"), ("孩童式", "child_pose"), ("child pose", "child_pose"),
        ("穿针式", "thread_needle"), ("穿针", "thread_needle"), ("开书式胸椎旋转", "thread_needle"), ("thread the needle", "thread_needle"),
        ("蝴蝶式", "butterfly"), ("蝴蝶坐", "butterfly"), ("束角式", "butterfly"), ("butterfly stretch", "butterfly"),
        ("哑铃卧推", "dumbbell_bench_press"), ("哑铃推胸", "dumbbell_bench_press"), ("dumbbell bench press", "dumbbell_bench_press"),
        ("哑铃地板卧推", "dumbbell_floor_press"), ("dumbbell floor press", "dumbbell_floor_press"), ("floor press", "dumbbell_floor_press"),
        ("哑铃罗马尼亚硬拉", "dumbbell_rdl"), ("dumbbell romanian deadlift", "dumbbell_rdl"), ("rdl", "dumbbell_rdl"),
        ("单腿罗马尼亚硬拉", "single_leg_rdl"), ("single leg rdl", "single_leg_rdl"), ("single-leg romanian deadlift", "single_leg_rdl"),
        ("单腿站姿提踵", "single_leg_calf_raise"), ("single leg calf raise", "single_leg_calf_raise"), ("one leg calf raise", "single_leg_calf_raise"),
        ("凳上反屈伸", "bench_dip"), ("凳上臂屈伸", "bench_dip"), ("bench dip", "bench_dip"),
        ("哑铃侧平举", "lateral_raise"), ("dumbbell lateral raise", "lateral_raise"), ("lateral raise", "lateral_raise"),
        ("哑铃弯举", "biceps_curl"), ("dumbbell curl", "biceps_curl"), ("biceps curl", "biceps_curl"),

        ("臀推", "hip_thrust"), ("臀冲", "hip_thrust"), ("卧凳臀推", "hip_thrust"), ("hip thrust", "hip_thrust"),
        ("单腿臀桥", "single_leg_glute_bridge"), ("单腿臀举", "single_leg_glute_bridge"),
        ("单腿桥", "single_leg_glute_bridge"), ("single leg glute bridge", "single_leg_glute_bridge"),
        ("蚌式开合", "clamshell"), ("蚌式", "clamshell"), ("蚌壳式", "clamshell"), ("clamshell", "clamshell"),
        ("侧卧抬腿", "side_lying_leg_raise"), ("侧躺抬腿", "side_lying_leg_raise"),
        ("侧抬腿", "side_lying_leg_raise"), ("side lying leg raise", "side_lying_leg_raise"),

        ("下巴回收", "chin_tuck"), ("收下巴", "chin_tuck"), ("颈部回收", "chin_tuck"), ("chin tuck", "chin_tuck"),
        ("肩胛后缩", "scapular_retraction"), ("肩胛骨后收", "scapular_retraction"),
        ("肩胛收紧", "scapular_retraction"), ("scapular retraction", "scapular_retraction"),
        ("靠墙天使", "wall_slide"), ("靠墙滑臂", "wall_slide"), ("墙面天使", "wall_slide"), ("wall slide", "wall_slide"),
        ("颈部等长", "neck_isometric"), ("颈部静力", "neck_isometric"),
        ("颈部等长收缩", "neck_isometric"), ("neck isometric", "neck_isometric")
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
                catalogId: ExerciseMergeMap.current.resolve(remembered),
                alias: rawName.trimmingCharacters(in: .whitespacesAndNewlines),
                modifier: nil,
                source: .memory
            )
        }

        guard let hit = aliasHit(name) else { return nil }
        return ExerciseMatch(
            catalogId: ExerciseMergeMap.current.resolve(hit.id),
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
