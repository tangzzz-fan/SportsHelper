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
    public var alternativeId: String?
    public var affectedParts: Set<BodyPart>
    public var relievedParts: Set<BodyPart>
    public var purposes: Set<ExercisePurpose>

    public init(
        id: String,
        name: String,
        group: ExerciseGroup,
        equipment: Equipment,
        isStatic: Bool,
        cues: [String],
        mistakes: [String],
        regressionName: String,
        regressionId: String? = nil,
        alternativeId: String? = nil,
        affectedParts: Set<BodyPart> = [],
        relievedParts: Set<BodyPart> = [],
        purposes: Set<ExercisePurpose> = [.strength]
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
        self.alternativeId = alternativeId
        self.affectedParts = affectedParts
        self.relievedParts = relievedParts
        self.purposes = purposes
    }

    public var tagText: String {
        isStatic ? "静力 · \(equipment.chineseName)" : equipment.chineseName
    }
}

public enum ExerciseLibrary {
    public static let all: [ExerciseEntry] = lowerEntries + upperEntries + coreEntries

    public static func entry(for id: String, merging map: ExerciseMergeMap = .current) -> ExerciseEntry? {
        let key = map.resolve(id)
        return all.first { $0.id == key }
    }

    public static var identifiers: Set<String> {
        Set(all.map(\.id))
    }

    public static func grouped() -> [(group: ExerciseGroup, entries: [ExerciseEntry])] {
        ExerciseGroup.allCases.map { group in
            (group, all.filter { $0.group == group })
        }
    }
}

/// 语音识别用的领域词表。
///
/// `SFSpeechRecognizer` 是通用中文模型，「靠墙天使」「肩胛后缩」「臀桥」这类
/// 健身领域的低频词经常被识别成同音词或拆成两段。`contextualStrings` 是苹果提供的
/// 偏置接口：把词表喂进去，识别器会优先往这些词上靠，不需要训练、不需要联网。
///
/// 词表**从动作目录自动生成**，所以新增动作时只要目录里加了条目，这里自动跟上，
/// 不存在"改了目录忘了改词表"的问题。
///
/// 注意：`contextualStrings` 有数量与长度上限（实践上每条几十字符、总量几百条以内
/// 表现最好），所以这里只放动作名与设备名，不放整句要点。
public enum SpeechVocabulary {
    /// 动作名 + 常用器械名 + 计划里高频出现的量词短语。
    public static let planTerms: [String] = {
        var terms: [String] = []

        for entry in ExerciseLibrary.all {
            terms.append(entry.name)
        }

        // 器械名：用户常说「哑铃卧推」「杠铃深蹲」，器械单独成词能被正确切分。
        terms.append(contentsOf: [
            "哑铃", "杠铃", "壶铃", "弹力带", "绳索", "器械", "史密斯机",
            "瑞士球", "药球", "单杠", "双杠", "长凳", "椅子", "墙面",
        ])

        // 计划里的结构与单位：语音输入整段计划时这些词出现频率极高。
        terms.append(contentsOf: [
            "组", "次", "秒", "分钟", "每侧", "左右各", "循环", "轮",
            "休息", "间歇", "热身", "拉伸", "第几组", "下一个",
        ])

        // 去重，保持稳定顺序（识别器对顺序不敏感，但便于测试快照）
        var seen = Set<String>()
        return terms.filter { seen.insert($0).inserted }
    }()
}
