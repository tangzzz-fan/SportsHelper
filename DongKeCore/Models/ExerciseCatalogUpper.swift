import Foundation

extension ExerciseLibrary {
    static let upperEntries: [ExerciseEntry] = [
        ExerciseEntry(
            id: "push_up",
            name: "俯卧撑",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["手略宽于肩，肘向下约 45 度", "身体从肩到踝成一条直线", "胸口接近地面再推起"],
            mistakes: ["塌腰或撅臀", "手肘向外张成 90 度"],
            regressionName: "跪姿俯卧撑",
            affectedParts: [.shoulderNeck, .wrist, .elbow]
        ),
        ExerciseEntry(
            id: "dumbbell_row",
            name: "哑铃划船",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["髋部折叠，背部保持平直", "哑铃贴近身体拉向髋侧", "肩胛先向后收，再带动手臂"],
            mistakes: ["靠腰部甩起来", "耸肩，用斜方肌代偿"],
            regressionName: "弹力带划船",
            affectedParts: [.lowerBack]
        ),
        ExerciseEntry(
            id: "shoulder_press",
            name: "哑铃推举",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["哑铃在肩侧，掌心向前", "向上推时不要耸肩", "下落到耳朵高度即可"],
            mistakes: ["腰部后仰借力", "推到顶点锁死手肘"],
            regressionName: "徒手推举",
            affectedParts: [.shoulderNeck]
        ),
        ExerciseEntry(
            id: "superman",
            name: "超人式",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["俯卧，手臂前伸", "同时抬起对侧手脚", "抬起时呼气，落下时吸气"],
            mistakes: ["抬得过高，腰椎过度后伸", "憋气发力"],
            regressionName: "对侧手脚交替抬起",
            affectedParts: [.lowerBack]
        ),
        ExerciseEntry(
            id: "arm_circle",
            name: "手臂绕环",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["双脚与肩同宽，双臂向两侧平举", "由小到大画圈，前后各 15 秒", "肩膀放松，不耸肩"],
            mistakes: ["画圈过快，靠甩臂带动", "只转手腕，肩没动"],
            regressionName: "单臂交替绕环",
            purposes: [.warmup]
        ),
        ExerciseEntry(
            id: "scapular_circle",
            name: "肩胛绕环",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["双臂自然下垂", "肩胛骨向后、向上、向前、向下画圈", "动作慢，感受肩胛在背上滑动"],
            mistakes: ["耸肩代替肩胛移动", "速度过快变成甩肩"],
            regressionName: "肩胛后缩保持",
            purposes: [.warmup]
        ),
        ExerciseEntry(
            id: "chest_stretch",
            name: "胸大肌拉伸",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["前臂扶门框，肘略高于肩", "身体前倾，肩胛后收", "感受胸前拉长，不憋气"],
            mistakes: ["肘过低变成拉肩前侧", "耸肩"],
            regressionName: "单手扶墙转体",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "neck_stretch",
            name: "颈肩拉伸",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["坐直，右手轻放左侧头部", "头向右侧倾，左肩下沉", "到有牵拉感即止，20 秒后换边"],
            mistakes: ["用手用力下压", "耸肩跟着歪"],
            regressionName: "下巴微收保持",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "thread_needle",
            name: "穿针式",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["四点跪姿，右手从左臂下方穿过", "右肩与右耳贴地", "保持 20 秒后换边"],
            mistakes: ["压头而不是转胸椎", "支撑手肘锁死"],
            regressionName: "跪姿胸椎旋转",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "dumbbell_bench_press",
            name: "哑铃卧推",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["卧凳调平或 30 度上斜，仰卧，哑铃在胸两侧", "肩胛后收下沉，肘约 45 度", "推到手臂接近伸直但不锁死"],
            mistakes: ["耸肩推", "手肘完全外展成 90 度"],
            regressionName: "哑铃地板卧推",
            affectedParts: [.shoulderNeck, .wrist, .elbow]
        ),
        ExerciseEntry(
            id: "dumbbell_floor_press",
            name: "哑铃地板卧推",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["仰卧地面，屈膝踩地", "哑铃下放到上臂触地", "推起时手腕保持中立"],
            mistakes: ["肘部砸地", "腰部离地过度反弓"],
            regressionName: "单臂地板卧推",
            affectedParts: [.shoulderNeck, .wrist, .elbow]
        ),
        ExerciseEntry(
            id: "lateral_raise",
            name: "哑铃侧平举",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["站姿，哑铃在体侧", "肘微屈，向侧抬到肩高", "小指略高于拇指"],
            mistakes: ["耸肩借力", "甩起来靠惯性"],
            regressionName: "弹力带侧平举",
            affectedParts: [.shoulderNeck]
        ),
        ExerciseEntry(
            id: "biceps_curl",
            name: "哑铃弯举",
            group: .upper,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["站姿，掌心向前", "肘固定在体侧，前臂上卷", "顶点停一下再慢放"],
            mistakes: ["肘前后晃", "靠腰部摆动借力"],
            regressionName: "弹力带弯举",
            affectedParts: [.elbow]
        )
    ]
}
