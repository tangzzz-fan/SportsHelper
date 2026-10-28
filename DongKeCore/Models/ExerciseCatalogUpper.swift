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
        ),
        ExerciseEntry(
            id: "chin_tuck",
            name: "下巴回收",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["坐直或靠墙站，眼睛平视前方", "下巴水平向后收，像做出双下巴", "保持 5 秒再放松，不要低头"],
            mistakes: ["低头代替后收", "用力过猛，脖子前侧发紧"],
            regressionName: "仰卧下巴回收",
            relievedParts: [.shoulderNeck],
            purposes: [.mobility]
        ),
        ExerciseEntry(
            id: "scapular_retraction",
            name: "肩胛后缩",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["坐或站直，双臂自然下垂", "两侧肩胛骨向后、向下收拢", "保持 5 秒，不要耸肩"],
            mistakes: ["耸肩代替后缩", "挺腰把胸口顶出去"],
            regressionName: "小幅肩胛后缩",
            relievedParts: [.shoulderNeck],
            purposes: [.mobility]
        ),
        ExerciseEntry(
            id: "wall_slide",
            name: "靠墙天使",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["背靠墙站，后脑、上背、臀部贴墙", "手臂贴墙成 W 形，沿墙面缓慢上滑", "到能力上限停住，再慢慢回到 W"],
            mistakes: ["腰离墙拱起", "手臂离开墙面借力"],
            regressionName: "靠墙手臂小幅上滑",
            relievedParts: [.shoulderNeck],
            purposes: [.mobility]
        ),
        ExerciseEntry(
            id: "neck_isometric",
            name: "颈部等长",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["坐直，手掌抵住额头", "头手互顶，脖子不动，保持 5 秒", "前后左右四个方向各做一次"],
            mistakes: ["头真的移动了", "憋气用力"],
            regressionName: "轻力度颈部等长",
            relievedParts: [.shoulderNeck],
            purposes: [.mobility]
        ),
        ExerciseEntry(
            id: "bench_dip",
            name: "凳上反屈伸",
            group: .upper,
            equipment: .bench,
            isStatic: false,
            cues: ["背对凳子，双手撑在边缘", "肘部向后弯，身体贴着凳子下沉", "下到肘弯约 90 度再推起"],
            mistakes: ["肩膀耸起", "下沉太深压到肩前侧"],
            regressionName: "直臂支撑",
            alternativeId: "biceps_curl",
            affectedParts: [.elbow, .shoulderNeck]
        ),
        ExerciseEntry(
            id: "banded_external_rotation",
            name: "弹力带肩外旋",
            group: .upper,
            equipment: .band,
            isStatic: false,
            cues: ["弹力带固定在体侧，与肘同高", "上臂夹紧体侧，屈肘 90 度", "只有前臂向外打开，打开时手比肘更远离身体"],
            mistakes: ["整条手臂外展，变成侧平举", "上臂离开体侧，靠身体转动代偿"],
            regressionName: "徒手肩外旋",
            purposes: [.strength]
        ),
        ExerciseEntry(
            id: "thoracic_extension",
            name: "胸椎伸展",
            group: .upper,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["仰卧，泡沫轴横放在肩胛骨下方", "双手抱头，只有上背向后展开", "骨盆贴地不动，展开时吸气"],
            mistakes: ["腰部跟着拱起，变成腰椎过伸", "臀部离地，用腰发力"],
            regressionName: "仰卧胸椎伸展（不用轴）",
            purposes: [.mobility]
        ),
        ExerciseEntry(
            id: "pendulum",
            name: "钟摆运动",
            group: .upper,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["身体前倾约 70 度，健侧手扶住桌面", "患侧手臂完全放松下垂，像钟摆一样画小圈", "靠身体带动，肩膀不要主动发力"],
            mistakes: ["主动抬手臂，变成侧平举", "身体直立，手臂贴着大腿摆不起来"],
            regressionName: "被动垂臂画圈",
            purposes: [.mobility]
        ),
    ]
}
