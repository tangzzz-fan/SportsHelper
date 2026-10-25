import Foundation

/// 一句话拆成音条的结果。
public enum VoiceClipPlan: Equatable, Sendable {
    /// 依次播放这些片段。
    case clips([String])
    /// 有片段不在库里（动作名之外的自由文本、超范围的数字、AI 生成的主题），整句交给系统 TTS。
    case fallback

    public var segments: [String] {
        if case let .clips(items) = self { return items }
        return []
    }
}

/// 音条库：把 `WorkoutAnnouncement` 吐出来的整句，切成一段一段**预录**的短语。
///
/// 为什么要切：整句是 43 个动作 × 组数 × 剂量 的组合，录不完；但短语是封闭的
/// （动作名 + 「第 N 组」+「共 N 组」+ 剂量 + 几个固定词），几百条就能覆盖绝大多数句子。
///
/// 切不出来就 `.fallback`，交给系统 TTS——**不允许静默无声**。
public enum VoiceClipBank {
    public static let setRange = 1...20
    public static let totalSetRange = 1...30
    public static let completedRange = 0...40
    public static let repsRange = 1...30
    public static let perSideRepsRange = 1...20
    public static let secondsRange = stride(from: 5, through: 120, by: 5)
    public static let minutesRange = 1...10
    public static let metersRange = stride(from: 10, through: 300, by: 10)
    public static let kilometersRange = 1...10
    public static let percentRange = stride(from: 0, through: 100, by: 5)
    public static let extrasRange = 1...5
    public static let bareDigitRange = 0...10

    public static let fixedPhrases = ["开始训练", "休息", "休息结束", "接下来"]

    /// 全部音条，去重后按字典序，供渲染脚本与测试使用。
    public static let inventory: [String] = {
        var phrases = Set<String>()
        phrases.formUnion(fixedPhrases)
        phrases.formUnion(ExerciseLibrary.all.map(\.name))
        for n in setRange { phrases.insert("第 \(n) 组") }
        for n in totalSetRange { phrases.insert("共 \(n) 组") }
        for n in completedRange { phrases.insert("完成 \(n) 组") }
        for n in extrasRange { phrases.insert("另有 \(n) 组加练") }
        for n in percentRange { phrases.insert("完成率 \(n)%") }
        for n in repsRange { phrases.insert("\(n) 次") }
        for n in perSideRepsRange { phrases.insert("每侧 \(n) 次") }
        for n in secondsRange { phrases.insert("\(n) 秒") }
        for n in minutesRange { phrases.insert("\(n) 分") }
        for n in metersRange { phrases.insert("\(n) 米") }
        for n in kilometersRange {
            phrases.insert("\(n) 公里")
            phrases.insert("每侧 \(n) 公里")
        }
        for n in bareDigitRange { phrases.insert("\(n)") }
        return phrases.sorted()
    }()

    private static let inventorySet = Set(inventory)
    private static let longestPhrase = inventory.map(\.count).max() ?? 1

    /// 稳定 id，渲染脚本与运行时共用。用 FNV-1a，不依赖哈希随机种子。
    public static func clipId(for phrase: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in phrase.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016lx", hash)
    }

    public static func plan(for text: String) -> VoiceClipPlan {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return .fallback }
        guard let clips = segments(in: trimmed) else { return .fallback }
        return .clips(clips)
    }

    public static func contains(_ phrase: String) -> Bool {
        inventorySet.contains(phrase)
    }

    /// 从左到右取最长匹配。分隔符（逗号、顿号、冒号、空格）跳过，其余字符匹配不上就判失败。
    private static func segments(in text: String) -> [String]? {
        let characters = Array(text)
        var index = 0
        var out: [String] = []

        while index < characters.count {
            let character = characters[index]
            if separators.contains(character) {
                index += 1
                continue
            }
            guard let phrase = longestMatch(in: characters, at: index) else { return nil }
            out.append(phrase)
            index += phrase.count
        }
        return out.isEmpty ? nil : out
    }

    private static func longestMatch(in characters: [Character], at start: Int) -> String? {
        let remaining = characters.count - start
        let upper = min(longestPhrase, remaining)
        guard upper > 0 else { return nil }
        for length in stride(from: upper, through: 1, by: -1) {
            let candidate = String(characters[start..<(start + length)])
            if inventorySet.contains(candidate) { return candidate }
        }
        return nil
    }

    private static let separators: Set<Character> = ["，", "、", "：", " ", "\n", ":", ","]
}
