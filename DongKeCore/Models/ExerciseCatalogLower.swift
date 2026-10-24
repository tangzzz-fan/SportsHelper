import Foundation

extension ExerciseLibrary {
    static let lowerEntries: [ExerciseEntry] = [
        ExerciseEntry(
            id: "squat",
            name: "深蹲",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["脚与肩同宽，脚尖略外八", "髋部先向后坐，膝盖顺着脚尖方向", "下蹲到大腿接近水平即可起身"],
            mistakes: ["膝盖内扣", "脚跟离地、重心压到前脚掌"],
            regressionName: "靠墙静蹲",
            regressionId: "wall_sit",
            alternativeId: "hip_thrust",
            affectedParts: [.knee, .hip]
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
            regressionId: "squat",
            alternativeId: "hip_thrust",
            affectedParts: [.knee, .hip]
        ),
        ExerciseEntry(
            id: "glute_bridge",
            name: "臀桥",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["仰卧屈膝，脚跟靠近臀部", "先收紧臀部再抬髋，别用腰发力", "顶点停一秒再落下"],
            mistakes: ["腰过度反弓", "靠腰部把身体顶起来"],
            regressionName: "幅度减半的臀桥",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "hip_thrust",
            name: "臀推",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["肩胛下缘靠在沙发或床沿，双脚与髋同宽", "收紧臀部把髋顶到躯干成一条线，别用腰反弓", "顶点停一秒，下巴微收，想加负荷就把哑铃放在髋上"],
            mistakes: ["腰过度反弓代替伸髋", "脚放得太远，变成腿后侧发力"],
            regressionName: "幅度减半的臀推",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "single_leg_glute_bridge",
            name: "单腿臀桥",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["仰卧屈膝，一只脚踩地，另一条腿伸直抬起", "用踩地那条腿把髋顶起，骨盆保持水平", "落下时控制住，别直接砸地"],
            mistakes: ["骨盆一侧下沉、左右不平", "抬起的腿勾脚借力"],
            regressionName: "双腿臀桥",
            regressionId: "glute_bridge",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "clamshell",
            name: "蚌式开合",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["侧卧屈膝约 90 度，脚跟并拢，髋部垂直地面", "脚跟不离，上侧膝盖向上打开", "打开到最大停一秒再慢慢合上，没有弹力带就空手做"],
            mistakes: ["骨盆跟着向后翻", "靠转腰代替髋外展"],
            regressionName: "小幅蚌式",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "side_lying_leg_raise",
            name: "侧卧抬腿",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["侧卧，下侧腿微屈，上侧腿伸直", "脚尖朝前，把腿抬到约 45 度", "落下时控制住，不要碰到下侧腿"],
            mistakes: ["腿向前甩", "骨盆后翻、身体变成半仰卧"],
            regressionName: "屈膝侧卧抬腿",
            affectedParts: []
        ),
        ExerciseEntry(
            id: "wall_sit",
            name: "靠墙静蹲",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["背贴墙、脚离墙约一脚半", "大腿接近水平，膝盖在脚踝正上方", "保持均匀呼吸，不憋气"],
            mistakes: ["膝盖超过脚尖", "手撑在大腿上借力"],
            regressionName: "浅角度靠墙静蹲",
            affectedParts: [.knee]
        ),
        ExerciseEntry(
            id: "calf_raise",
            name: "提踵",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["前脚掌踩实，脚跟慢慢抬到最高", "顶点停一秒，再缓慢落下", "可以扶墙保持平衡"],
            mistakes: ["靠弹震借力", "落得太快，没有离心控制"],
            regressionName: "扶墙双脚提踵",
            affectedParts: [.ankle]
        ),
        ExerciseEntry(
            id: "jumping_jack",
            name: "开合跳",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["起跳时双脚外展、双手上举", "落地屈膝缓冲，前脚掌先着地", "保持节奏均匀"],
            mistakes: ["落地直腿硬砸", "手臂只抬到肩高"],
            regressionName: "原地踏步开合",
            affectedParts: [.knee, .ankle],
            purposes: [.warmup, .strength]
        ),
        ExerciseEntry(
            id: "high_knees",
            name: "高抬腿",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["大腿抬到接近水平", "前脚掌落地，频率稳定", "躯干保持直立"],
            mistakes: ["上身后仰", "脚掌砸地"],
            regressionName: "原地踏步",
            affectedParts: [.knee, .ankle],
            purposes: [.warmup, .strength]
        ),
        ExerciseEntry(
            id: "march_in_place",
            name: "原地踏步",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["站直，原地交替抬膝到髋部高度", "手臂自然摆动，呼吸均匀", "落地轻，前脚掌先着地"],
            mistakes: ["抬膝过高导致腰部代偿", "落地砸地"],
            regressionName: "扶墙原地踏步",
            purposes: [.warmup]
        ),
        ExerciseEntry(
            id: "hip_circle",
            name: "髋绕环",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["双手扶髋，双脚略宽于肩", "骨盆画大圈，顺逆时针各 10 次", "上身保持稳定，只有骨盆动"],
            mistakes: ["靠扭腰代替转髋", "膝盖跟着内扣"],
            regressionName: "小幅髋前后倾",
            purposes: [.warmup]
        ),
        ExerciseEntry(
            id: "ankle_circle",
            name: "踝绕环",
            group: .lower,
            equipment: .bodyweight,
            isStatic: false,
            cues: ["单脚点地，脚尖画圈", "顺逆时针各 10 次", "幅度由小到大"],
            mistakes: ["整条腿跟着转", "速度过快"],
            regressionName: "踝泵",
            purposes: [.warmup]
        ),
        ExerciseEntry(
            id: "quad_stretch",
            name: "股四头肌拉伸",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["单手扶墙，另一手抓同侧脚踝", "脚跟拉向臀部，膝盖朝下", "髋部前推，感受大腿前侧"],
            mistakes: ["膝盖向外打开", "腰部反弓代偿"],
            regressionName: "侧卧股四头肌拉伸",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "hamstring_stretch",
            name: "腘绳肌拉伸",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["一脚放矮台或椅面，腿伸直", "从髋部折叠，胸口靠向伸直的腿", "背保持直，不弓腰"],
            mistakes: ["弓背去够脚尖", "膝盖锁死过伸"],
            regressionName: "仰卧单腿拉伸",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "hip_flexor_stretch",
            name: "髋前侧拉伸",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["单膝跪地成弓步", "骨盆后倾，髋部向前推", "感受后腿髋前侧拉长"],
            mistakes: ["腰部反弓代替髋前推", "前膝超过脚尖太多"],
            regressionName: "站姿扶墙髋前侧拉伸",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "calf_stretch",
            name: "小腿拉伸",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["面向墙，双手扶墙", "后腿伸直、脚跟踩地", "身体前倾，感受小腿后侧"],
            mistakes: ["后脚跟离地", "脚尖外八"],
            regressionName: "坐姿毛巾拉伸",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "butterfly",
            name: "蝴蝶式",
            group: .lower,
            equipment: .bodyweight,
            isStatic: true,
            cues: ["坐姿，脚掌相对，膝盖向两侧打开", "双手握脚，脊柱向上延伸", "从髋部前倾，不弓背"],
            mistakes: ["用手压膝盖", "弓背去够脚"],
            regressionName: "单腿屈膝开髋",
            purposes: [.stretch]
        ),
        ExerciseEntry(
            id: "dumbbell_rdl",
            name: "哑铃罗马尼亚硬拉",
            group: .lower,
            equipment: .dumbbell,
            isStatic: false,
            cues: ["站姿，哑铃在大腿前", "髋部后移，膝盖微屈", "下放到小腿中段，感受腿后侧拉长"],
            mistakes: ["弓背下放", "靠弯腰代替髋铰链"],
            regressionName: "徒手髋铰链",
            alternativeId: "hip_thrust",
            affectedParts: [.lowerBack, .hip]
        ),
    ]
}
