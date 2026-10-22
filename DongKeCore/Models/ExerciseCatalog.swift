import Foundation

public enum ExerciseGroup: String, CaseIterable, Sendable {
    case lower
    case upper
    case core

    public var title: String {
        switch self {
        case .lower: "下肢"
        case .upper: "上肢"
        case .core: "核心"
        }
    }
}

public struct ExerciseEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var group: ExerciseGroup
    public var equipment: Equipment
    public var isStatic: Bool
    public var cues: [String]
    public var mistakes: [String]
    public var regressionName: String
    public var regressionId: String?

    public init(
        id: String,
        name: String,
        group: ExerciseGroup,
        equipment: Equipment,
        isStatic: Bool,
        cues: [String],
        mistakes: [String],
        regressionName: String,
        regressionId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.equipment = equipment
        self.isStatic = isStatic
        self.cues = cues
        self.mistakes = mistakes
        self.regressionName = regressionName
        self.regressionId = regressionId
    }

    public var tagText: String {
        isStatic ? "静力 · \(equipment.chineseName)" : equipment.chineseName
    }
}

public enum ExerciseLibrary {
    public static let all: [ExerciseEntry] = [
        ExerciseEntry(
            id: "squat",
            name: "深蹲",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["脚与肩同宽，脚尖略外八", "髋部先向后坐，膝盖顺着脚尖方向", "下蹲到大腿接近水平即可起身"],
            mistakes: ["膝盖内扣", "脚跟离地、重心压到前脚掌"],
            regressionName: "靠墙静蹲",
            regressionId: "wall_sit"
        ),
        ExerciseEntry(
            id: "lunge",
            name: "弓步蹲",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["前后脚分开约一大步", "下沉时前膝不超过脚尖太多", "躯干保持直立，不前倾"],
            mistakes: ["步子太窄，膝盖顶到地面", "身体左右晃"],
            regressionName: "徒手深蹲",
            regressionId: "squat"
        ),
        ExerciseEntry(
            id: "glute_bridge",
            name: "臀桥",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["仰卧屈膝，脚跟靠近臀部", "先收紧臀部再抬髋，别用腰发力", "顶点停一秒再落下"],
            mistakes: ["腰过度反弓", "靠腰部把身体顶起来"],
            regressionName: "幅度减半的臀桥"
        ),
        ExerciseEntry(
            id: "wall_sit",
            name: "靠墙静蹲",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["背贴墙、脚离墙约一脚半", "大腿接近水平，膝盖在脚踝正上方", "保持均匀呼吸，不憋气"],
            mistakes: ["膝盖超过脚尖", "手撑在大腿上借力"],
            regressionName: "浅角度靠墙静蹲"
        ),
        ExerciseEntry(
            id: "calf_raise",
            name: "提踵",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["前脚掌踩实，脚跟慢慢抬到最高", "顶点停一秒，再缓慢落下", "可以扶墙保持平衡"],
            mistakes: ["靠弹震借力", "落得太快，没有离心控制"],
            regressionName: "扶墙双脚提踵"
        ),
        ExerciseEntry(
            id: "push_up",
            name: "俯卧撑",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["手略宽于肩，肘向下约 45 度", "身体从肩到踝成一条直线", "胸口接近地面再推起"],
            mistakes: ["塌腰或撅臀", "手肘向外张成 90 度"],
            regressionName: "跪姿俯卧撑"
        ),
        ExerciseEntry(
            id: "dumbbell_row",
            name: "哑铃划船",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["髋部折叠，背部保持平直", "哑铃贴近身体拉向髋侧", "肩胛先向后收，再带动手臂"],
            mistakes: ["靠腰部甩起来", "耸肩，用斜方肌代偿"],
            regressionName: "弹力带划船"
        ),
        ExerciseEntry(
            id: "shoulder_press",
            name: "哑铃推举",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["哑铃在肩侧，掌心向前", "向上推时不要耸肩", "下落到耳朵高度即可"],
            mistakes: ["腰部后仰借力", "推到顶点锁死手肘"],
            regressionName: "徒手推举"
        ),
        ExerciseEntry(
            id: "superman",
            name: "超人式",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["俯卧，手臂前伸", "同时抬起对侧手脚", "抬起时呼气，落下时吸气"],
            mistakes: ["抬得过高，腰椎过度后伸", "憋气发力"],
            regressionName: "对侧手脚交替抬起"
        ),
        ExerciseEntry(
            id: "bird_dog",
            name: "鸟狗",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["四点支撑，手腕在肩下", "对侧手脚同时伸直，骨盆保持水平", "停两秒再换边"],
            mistakes: ["骨盆跟着腿转", "抬头或低头看地"],
            regressionName: "只抬腿或只抬手"
        ),
        ExerciseEntry(
            id: "dead_bug",
            name: "死虫",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["仰卧，腰贴地，手脚朝天", "对侧手脚缓慢放低", "腰始终不离开地面"],
            mistakes: ["腰离地拱起", "动作太快，靠惯性"],
            regressionName: "单腿放下"
        ),
        ExerciseEntry(
            id: "crunch",
            name: "卷腹",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["屈膝仰卧，下巴微收", "用腹部把肩胛卷离地面", "起身呼气，落下吸气"],
            mistakes: ["用手拉脖子", "靠惯性甩起上身"],
            regressionName: "幅度减半的卷腹"
        ),
        ExerciseEntry(
            id: "russian_twist",
            name: "俄罗斯转体",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["坐姿屈膝，身体略后倾", "转体时肩膀跟着走，不只是手", "保持脚不落地或轻触地"],
            mistakes: ["只摆手臂不转躯干", "弓背含胸"],
            regressionName: "双脚落地转体"
        ),
        ExerciseEntry(
            id: "plank",
            name: "平板支撑",
            group: .core,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["肘在肩正下方，小臂贴地", "臀部和腹部一起收紧", "头、肩、髋、踝成一条线"],
            mistakes: ["塌腰翘臀", "抬头看前方"],
            regressionName: "膝盖着地平板"
        ),
        ExerciseEntry(
            id: "side_plank",
            name: "侧平板",
            group: .core,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["肘在肩下，身体侧向支撑", "髋部向上顶，不要下沉", "两侧各做同样时间"],
            mistakes: ["髋部塌向地面", "肩膀耸起"],
            regressionName: "屈膝侧平板"
        ),
        ExerciseEntry(
            id: "jumping_jack",
            name: "开合跳",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["起跳时双脚外展、双手上举", "落地屈膝缓冲，前脚掌先着地", "保持节奏均匀"],
            mistakes: ["落地直腿硬砸", "手臂只抬到肩高"],
            regressionName: "原地踏步开合"
        ),
        ExerciseEntry(
            id: "high_knees",
            name: "高抬腿",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["大腿抬到接近水平", "前脚掌落地，频率稳定", "躯干保持直立"],
            mistakes: ["上身后仰", "脚掌砸地"],
            regressionName: "原地踏步"
        ),
        ExerciseEntry(
            id: "mountain_climber",
            name: "登山跑",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["手撑地成俯卧撑起始位", "交替把膝盖收向胸口", "肩保持在手腕正上方"],
            mistakes: ["臀部翘起或塌腰", "只动腿不动核心"],
            regressionName: "慢速登山"
        )
    ]

    public static func entry(for id: String) -> ExerciseEntry? {
        all.first { $0.id == id }
    }

    public static func grouped() -> [(group: ExerciseGroup, entries: [ExerciseEntry])] {
        ExerciseGroup.allCases.map { group in
            (group, all.filter { $0.group == group })
        }
    }
}
