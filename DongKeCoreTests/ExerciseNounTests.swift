import Foundation
import Testing
@testable import DongKeCore

@Suite("动作名词覆盖")
struct ExerciseNounTests {

    private func id(_ name: String) -> String? {
        ExerciseAliasResolver.match(for: name)?.catalogId
    }

    @Test("下肢动作的口语、器械与英文写法都归位")
    func lowerBodyNouns() {
        let cases: [(String, String)] = [
            ("深蹲", "squat"), ("徒手深蹲", "squat"), ("自重深蹲", "squat"), ("空气深蹲", "squat"),
            ("徒手蹲", "squat"), ("下蹲", "squat"), ("蹲起", "squat"), ("标准深蹲", "squat"),
            ("squat", "squat"), ("Squats", "squat"), ("air squat", "squat"), ("bodyweight squat", "squat"),
            ("弓步蹲", "lunge"), ("箭步蹲", "lunge"), ("剑步蹲", "lunge"), ("弓步", "lunge"), ("箭步", "lunge"),
            ("分腿蹲", "lunge"), ("单腿蹲", "lunge"), ("前弓步", "lunge"), ("后撤步蹲", "lunge"), ("剪蹲", "lunge"),
            ("lunge", "lunge"), ("forward lunge", "lunge"), ("reverse lunge", "lunge"),
            ("walking lunge", "lunge"), ("split squat", "lunge"), ("bulgarian split squat", "lunge"),
            ("臀桥", "glute_bridge"), ("桥式", "glute_bridge"), ("臀举", "glute_bridge"),
            ("仰卧挺髋", "glute_bridge"), ("挺髋", "glute_bridge"),
            ("glute bridge", "glute_bridge"), ("hip bridge", "glute_bridge"), ("bridge", "glute_bridge"),
            ("臀推", "hip_thrust"), ("臀冲", "hip_thrust"), ("卧凳臀推", "hip_thrust"),
            ("hip thrust", "hip_thrust"),
            ("单腿臀桥", "single_leg_glute_bridge"), ("单腿桥", "single_leg_glute_bridge"),
            ("single leg glute bridge", "single_leg_glute_bridge"),
            ("蚌式开合", "clamshell"), ("蚌式", "clamshell"), ("clamshell", "clamshell"),
            ("侧卧抬腿", "side_lying_leg_raise"), ("侧躺抬腿", "side_lying_leg_raise"),
            ("side lying leg raise", "side_lying_leg_raise"),
            ("靠墙静蹲", "wall_sit"), ("靠墙蹲", "wall_sit"), ("靠墙深蹲", "wall_sit"), ("靠墙马步", "wall_sit"),
            ("静蹲", "wall_sit"), ("墙蹲", "wall_sit"), ("wall sit", "wall_sit"), ("wall squat", "wall_sit"),
            ("提踵", "calf_raise"), ("站姿提踵", "calf_raise"), ("踮脚", "calf_raise"), ("提脚跟", "calf_raise"),
            ("calf raise", "calf_raise"), ("heel raise", "calf_raise"),
            ("开合跳", "jumping_jack"), ("跳开合", "jumping_jack"), ("星星跳", "jumping_jack"),
            ("jumping jack", "jumping_jack"), ("jumping jacks", "jumping_jack"), ("star jump", "jumping_jack"),
            ("高抬腿", "high_knees"), ("原地高抬腿", "high_knees"), ("高抬腿跑", "high_knees"),
            ("high knees", "high_knees"), ("high knee", "high_knees")
        ]
        for (name, expected) in cases {
            #expect(id(name) == expected, "「\(name)」应识别为 \(expected)，实际 \(id(name) ?? "nil")")
        }
    }

    @Test("上肢动作的同义词与英文写法都归位")
    func upperBodyNouns() {
        let cases: [(String, String)] = [
            ("俯卧撑", "push_up"), ("伏地挺身", "push_up"), ("掌上压", "push_up"), ("标准俯卧撑", "push_up"),
            ("push up", "push_up"), ("Push-Up", "push_up"), ("pushup", "push_up"), ("press up", "push_up"),
            ("哑铃划船", "dumbbell_row"), ("划船", "dumbbell_row"), ("单臂划船", "dumbbell_row"),
            ("俯身划船", "dumbbell_row"), ("坐姿划船", "dumbbell_row"), ("弹力带划船", "dumbbell_row"),
            ("壶铃划船", "dumbbell_row"), ("row", "dumbbell_row"), ("dumbbell row", "dumbbell_row"),
            ("bent over row", "dumbbell_row"), ("one arm row", "dumbbell_row"),
            ("哑铃推举", "shoulder_press"), ("肩推", "shoulder_press"), ("推举", "shoulder_press"),
            ("站姿推举", "shoulder_press"), ("军事推举", "shoulder_press"), ("过头推举", "shoulder_press"),
            ("肩上推举", "shoulder_press"), ("shoulder press", "shoulder_press"),
            ("overhead press", "shoulder_press"), ("military press", "shoulder_press"),
            ("超人", "superman"), ("超人式", "superman"), ("超人挺身", "superman"),
            ("小燕飞", "superman"), ("燕飞", "superman"), ("superman", "superman")
        ]
        for (name, expected) in cases {
            #expect(id(name) == expected, "「\(name)」应识别为 \(expected)，实际 \(id(name) ?? "nil")")
        }
    }

    @Test("核心动作的同义词与英文写法都归位")
    func coreNouns() {
        let cases: [(String, String)] = [
            ("鸟狗", "bird_dog"), ("鸟狗式", "bird_dog"), ("四点支撑", "bird_dog"), ("对侧支撑", "bird_dog"),
            ("bird dog", "bird_dog"), ("bird-dog", "bird_dog"), ("birddog", "bird_dog"),
            ("死虫", "dead_bug"), ("死虫式", "dead_bug"), ("死虫动作", "dead_bug"), ("仰卧伸腿", "dead_bug"),
            ("dead bug", "dead_bug"), ("deadbug", "dead_bug"),
            ("卷腹", "crunch"), ("仰卧卷腹", "crunch"), ("腹肌卷腹", "crunch"), ("半程仰卧起坐", "crunch"),
            ("crunch", "crunch"), ("abdominal crunch", "crunch"),
            ("俄罗斯转体", "russian_twist"), ("俄罗斯旋体", "russian_twist"), ("转体", "russian_twist"),
            ("坐姿转体", "russian_twist"), ("负重转体", "russian_twist"),
            ("russian twist", "russian_twist"), ("russian twists", "russian_twist"),
            ("平板支撑", "plank"), ("平板撑", "plank"), ("平板", "plank"), ("肘撑", "plank"),
            ("平板支掌", "plank"), ("前臂平板", "plank"), ("plank", "plank"), ("forearm plank", "plank"),
            ("侧平板支撑", "side_plank"), ("侧平板", "side_plank"), ("侧支撑", "side_plank"),
            ("侧桥", "side_plank"), ("侧身平板", "side_plank"),
            ("side plank", "side_plank"), ("side bridge", "side_plank"),
            ("登山跑", "mountain_climber"), ("登山者", "mountain_climber"), ("登山式", "mountain_climber"),
            ("爬山式", "mountain_climber"), ("爬山跑", "mountain_climber"), ("俯卧提膝", "mountain_climber"),
            ("mountain climber", "mountain_climber"), ("mountain climbers", "mountain_climber")
        ]
        for (name, expected) in cases {
            #expect(id(name) == expected, "「\(name)」应识别为 \(expected)，实际 \(id(name) ?? "nil")")
        }
    }

    @Test("带限定词的变式要打橙标，而不是静默认成标准动作")
    func variantsAreFlagged() {
        let cases: [(String, String, String)] = [
            ("杠铃深蹲", "squat", "杠铃"),
            ("箱式深蹲", "squat", "箱式"),
            ("宽距深蹲", "squat", "宽距"),
            ("深蹲跳", "squat", "跳"),
            ("保加利亚分腿蹲", "lunge", "保加利亚"),
            ("跪姿俯卧撑", "push_up", "跪姿"),
            ("钻石俯卧撑", "push_up", "钻石"),
            ("窄距俯卧撑", "push_up", "窄距"),
            ("上斜俯卧撑", "push_up", "上斜"),
            ("单臂划船", "dumbbell_row", "单臂"),
            ("坐姿划船", "dumbbell_row", "坐姿"),
            ("俯身划船", "dumbbell_row", "俯身"),
            ("划船机", "dumbbell_row", "机"),
            ("坐姿推举", "shoulder_press", "坐姿")
        ]
        for (name, expectedId, expectedModifier) in cases {
            let hit = ExerciseAliasResolver.match(for: name)
            #expect(hit?.catalogId == expectedId, "「\(name)」应归到 \(expectedId)")
            #expect(hit?.modifier == expectedModifier, "「\(name)」应标出「\(expectedModifier)」，实际 \(hit?.modifier ?? "nil")")
            #expect(hit?.needsReview == true)
        }
    }

    @Test("标准动作名不该被当成猜测")
    func plainNamesAreNotFlagged() {
        for name in ["深蹲", "臀桥", "平板支撑", "靠墙静蹲", "哑铃划船", "超人式", "侧平板", "登山跑"] {
            let hit = ExerciseAliasResolver.match(for: name)
            #expect(hit?.modifier == nil, "「\(name)」不该被标成变式")
            #expect(hit?.needsReview == false)
        }
    }

    @Test("繁体写法也能落到同一个类型")
    func traditionalChinese() {
        let cases: [(String, String)] = [
            ("啞鈴划船", "dumbbell_row"), ("靠牆靜蹲", "wall_sit"), ("側平板支撐", "side_plank"),
            ("開合跳", "jumping_jack"), ("俄羅斯轉體", "russian_twist"), ("臀橋", "glute_bridge"),
            ("捲腹", "crunch"), ("俯臥撐", "push_up"), ("死蟲", "dead_bug"), ("鳥狗", "bird_dog"),
            ("單腿蹲", "lunge"), ("啞鈴推舉", "shoulder_press")
        ]
        for (name, expected) in cases {
            #expect(id(name) == expected, "繁体「\(name)」应识别为 \(expected)，实际 \(id(name) ?? "nil")")
        }
    }

    @Test("别名表自洽：每条别名都命中自己声明的动作")
    func aliasTableIsConsistent() {
        for (alias, expected) in ExerciseAliasResolver.aliases {
            #expect(id(alias) == expected, "别名「\(alias)」应命中 \(expected)，实际 \(id(alias) ?? "nil")")
        }
    }

    @Test("别名表没有同名指向两个动作")
    func aliasTableHasNoConflicts() {
        var seen: [String: String] = [:]
        for (alias, id) in ExerciseAliasResolver.aliases {
            let key = ExerciseAliasResolver.normalize(alias)
            if let existing = seen[key] {
                #expect(existing == id, "别名「\(alias)」同时指向 \(existing) 与 \(id)")
            } else {
                seen[key] = id
            }
        }
    }

    @Test("18 个内置动作都至少有 3 个叫法，且自己的名字能认出自己")
    func everyEntryHasEnoughAliases() {
        let validIds = Set(ExerciseLibrary.all.map(\.id))
        for entry in ExerciseLibrary.all {
            #expect(validIds.contains(entry.id))
            #expect(id(entry.name) == entry.id, "「\(entry.name)」认不出自己")

            let count = ExerciseAliasResolver.aliases.filter { $0.id == entry.id }.count
            #expect(count >= 3, "\(entry.id) 只有 \(count) 个叫法")
        }
        let aliasIds = Set(ExerciseAliasResolver.aliases.map(\.id))
        #expect(aliasIds.isSubset(of: validIds), "别名表里出现了不存在的动作 id：\(aliasIds.subtracting(validIds))")
    }
}
