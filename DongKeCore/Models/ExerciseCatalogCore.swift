import Foundation

extension ExerciseLibrary {
    static let coreEntries: [ExerciseEntry] = [
        ExerciseEntry(
            id: "bird_dog",
            name: "鸟狗",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["四点支撑，手腕在肩下", "对侧手脚同时伸直，骨盆保持水平", "停两秒再换边"],
            mistakes: ["骨盆跟着腿转", "抬头或低头看地"],
            regressionName: "只抬腿或只抬手",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "dead_bug",
            name: "死虫",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["仰卧，腰贴地，手脚朝天", "对侧手脚缓慢放低", "腰始终不离开地面"],
            mistakes: ["腰离地拱起", "动作太快，靠惯性"],
            regressionName: "单腿放下",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "crunch",
            name: "卷腹",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["屈膝仰卧，下巴微收", "用腹部把肩胛卷离地面", "起身呼气，落下吸气"],
            mistakes: ["用手拉脖子", "靠惯性甩起上身"],
            regressionName: "幅度减半的卷腹",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "russian_twist",
            name: "俄罗斯转体",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["坐姿屈膝，身体略后倾", "转体时肩膀跟着走，不只是手", "保持脚不落地或轻触地"],
            mistakes: ["只摆手臂不转躯干", "弓背含胸"],
            regressionName: "双脚落地转体",
            affectedParts: [.lowerBack]
        ),
        ExerciseEntry(
            id: "plank",
            name: "平板支撑",
            group: .core,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["肘在肩正下方，小臂贴地", "臀部和腹部一起收紧", "头、肩、髋、踝成一条线"],
            mistakes: ["塌腰翘臀", "抬头看前方"],
            regressionName: "膝盖着地平板",
            affectedParts: [.wrist]
        ),
        ExerciseEntry(
            id: "side_plank",
            name: "侧平板",
            group: .core,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["肘在肩下，身体侧向支撑", "髋部向上顶，不要下沉", "两侧各做同样时间"],
            mistakes: ["髋部塌向地面", "肩膀耸起"],
            regressionName: "屈膝侧平板",
            affectedParts: [.wrist, .shoulderNeck]
        ),
        ExerciseEntry(
            id: "mountain_climber",
            name: "登山跑",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["手撑地成俯卧撑起始位", "交替把膝盖收向胸口", "肩保持在手腕正上方"],
            mistakes: ["臀部翘起或塌腰", "只动腿不动核心"],
            regressionName: "慢速登山",
            affectedParts: [.wrist],
            purposes: [.warmup, .strength]
        ),
        ExerciseEntry(
            id: "cat_cow",
            name: "猫牛式",
            group: .core,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["四点跪姿，手在肩下、膝在髋下", "吸气塌腰抬头，呼气拱背低头", "脊柱一节一节动"],
            mistakes: ["只动腰不动胸椎", "手肘锁死"],
            regressionName: "坐姿脊柱前后倾",
            purposes: [.warmup, .mobility]
        ),
        ExerciseEntry(
            id: "back_stretch",
            name: "背部拉伸",
            group: .core,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["仰卧团身，双手抱膝", "下巴微收，背部贴地", "保持均匀呼吸"],
            mistakes: ["抬头用力", "抱膝过紧导致颈部紧张"],
            regressionName: "单侧抱膝",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "child_pose",
            name: "婴儿式",
            group: .core,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["跪坐，臀部坐向脚跟", "手臂前伸，额头贴地", "呼吸到后背，保持 30 秒"],
            mistakes: ["膝不适仍强行跪坐", "肩膀耸起"],
            regressionName: "坐姿前屈",
            purposes: [.stretch]
        ),
    ]
}
