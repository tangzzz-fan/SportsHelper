import Foundation

public enum PlanBriefParser {
    private static let maxSentenceCharacters = 200

    public static func parse(_ raw: String) -> PlanBrief {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return PlanBrief(sentence: "", isVague: true)
        }

        let sentence = String(trimmed.prefix(maxSentenceCharacters))
        let text = TextNormalization.normalize(sentence)
        var unparsed: [String] = []
        if trimmed.count > maxSentenceCharacters {
            unparsed.append("描述超过 \(maxSentenceCharacters) 字，只取前 \(maxSentenceCharacters) 字")
        }

        let weekdays = parseWeekdays(text)
        let daysPerWeek = weekdays == nil ? parseDaysPerWeek(text, unparsed: &unparsed) : nil
        if text.contains("隔天") {
            unparsed.append("「隔天」没有换算成具体星期，请在确认页选")
        }
        let sessionMinutes = parseSessionMinutes(text, unparsed: &unparsed)
        let equipment = parseEquipment(text, unparsed: &unparsed)
        let goal = parseGoal(text)
        let avoid = parseAvoid(text)
        let focus = parseFocus(text, avoiding: avoid)

        let hasSignal = weekdays != nil
            || daysPerWeek != nil
            || sessionMinutes != nil
            || equipment != nil
            || goal != nil
            || focus.isEmpty == false
            || avoid.isEmpty == false
        let vagueWords = ["随便", "你定", "看着办", "都行", "无所谓", "你安排", "没有要求", "没有特别", "都可以"]
        let isVague = hasSignal == false && vagueWords.contains { text.contains($0) }

        return PlanBrief(
            sentence: sentence,
            weekdays: weekdays,
            daysPerWeek: daysPerWeek,
            sessionMinutes: sessionMinutes,
            equipment: equipment,
            goal: goal,
            focus: focus,
            avoid: avoid,
            unparsed: unparsed,
            isVague: isVague
        )
    }

    // MARK: - 星期

    private static func parseWeekdays(_ text: String) -> [Weekday]? {
        let source = blankingFrequencyPhrases(text)
            .replacingOccurrences(of: "每天|天天", with: " ", options: .regularExpression)
        var found: [Weekday] = []

        if source.contains("周末") {
            found.append(contentsOf: [.saturday, .sunday])
        }

        for groups in matches("(?:周|星期|礼拜)\\s*([一二三四五六日天](?:\\s*[、,，和及]?\\s*[一二三四五六日天]){0,6})", in: source) {
            for character in groups.first ?? "" {
                if let day = weekday(character) { found.append(day) }
            }
        }

        for groups in matches("(?<!第)([一二三四五六日天]{2,})(?![次个天])", in: source) {
            for character in groups.first ?? "" {
                if let day = weekday(character) { found.append(day) }
            }
        }

        for groups in matches("\\b(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)[a-z]*\\b", in: source) {
            if let day = englishWeekday(groups.first ?? "") { found.append(day) }
        }

        let unique = uniqued(found).sorted { $0.rawValue < $1.rawValue }
        return unique.isEmpty ? nil : unique
    }

    /// 「每周三天」「一周三练」里的 周三 不是星期三。
    private static func blankingFrequencyPhrases(_ text: String) -> String {
        text.replacingOccurrences(
            of: "(?:每(?:个)?|一(?:个)?)(?:周|星期|礼拜)\\s*([0-9]+|[一二三四五六七两])\\s*(?:天|次|练)",
            with: " ",
            options: .regularExpression
        )
    }

    private static func weekday(_ character: Character) -> Weekday? {
        switch character {
        case "一": .monday
        case "二": .tuesday
        case "三": .wednesday
        case "四": .thursday
        case "五": .friday
        case "六": .saturday
        case "日", "天": .sunday
        default: nil
        }
    }

    private static func englishWeekday(_ token: String) -> Weekday? {
        switch token.lowercased().prefix(3) {
        case "mon": .monday
        case "tue": .tuesday
        case "wed": .wednesday
        case "thu": .thursday
        case "fri": .friday
        case "sat": .saturday
        case "sun": .sunday
        default: nil
        }
    }

    // MARK: - 频率

    private static func parseDaysPerWeek(_ text: String, unparsed: inout [String]) -> Int? {
        if text.contains("每天") || text.contains("天天") {
            return 7
        }

        let patterns = [
            "(?:每周|一周|每星期|每个星期|一个星期)[^，。；,;]{0,6}?([0-9]+|[一二三四五六七两])\\s*(?:天|次|练)",
            "(?:练|训练|安排)[^，。；,;]{0,4}?([0-9]+|[一二三四五六七两])\\s*天",
            "^\\s*([0-9]+|[一二三四五六七两])\\s*天",
            "^\\s*([0-9]+|[一二三四五六七两])\\s*次"
        ]

        for pattern in patterns {
            guard let raw = firstCapture(pattern, in: text) else { continue }
            guard let value = Int(raw) ?? TextNormalization.number(of: raw) else { continue }
            guard (1...7).contains(value) else {
                unparsed.append("每周 \(value) 天超出 1–7 天")
                return nil
            }
            return value
        }
        return nil
    }

    // MARK: - 时长

    private static func parseSessionMinutes(_ text: String, unparsed: inout [String]) -> Int? {
        if let groups = matches("([0-9]+(?:\\.[0-9]+)?)\\s*[-~到至]\\s*([0-9]+(?:\\.[0-9]+)?)\\s*(?:分钟|分|min)", in: text).first,
           groups.count > 1,
           let upper = Double(groups[1]) {
            return validatedMinutes(upper, unparsed: &unparsed)
        }

        if text.contains("一个半小时") || text.contains("1个半小时") {
            return 90
        }

        if let raw = firstCapture("([0-9]+(?:\\.[0-9]+)?)\\s*(?:小时|h\\b)", in: text),
           let hours = Double(raw) {
            return validatedMinutes(hours * 60, unparsed: &unparsed)
        }

        if text.contains("半小时") {
            return 30
        }

        if let raw = firstCapture("([0-9]+(?:\\.[0-9]+)?)\\s*(?:分钟|分|min)", in: text),
           let minutes = Double(raw) {
            return validatedMinutes(minutes, unparsed: &unparsed)
        }

        return nil
    }

    private static func validatedMinutes(_ raw: Double, unparsed: inout [String]) -> Int? {
        let minutes = Int(raw.rounded())
        guard (5...120).contains(minutes) else {
            unparsed.append("单次 \(minutes) 分钟超出 5–120 分钟")
            return nil
        }
        return minutes
    }

    // MARK: - 器械

    private static func parseEquipment(_ text: String, unparsed: inout [String]) -> [Equipment]? {
        var result: [Equipment] = []
        if text.contains("哑铃") { result.append(.dumbbell) }
        if text.contains("弹力带") || text.contains("阻力带") { result.append(.band) }
        if text.contains("壶铃") { result.append(.kettlebell) }
        if text.contains("卧凳") || text.contains("哑铃凳") || text.lowercased().contains("bench") {
            result.append(.bench)
        }

        for word in ["杠铃", "跑步机", "龙门架", "史密斯", "器械"] where text.contains(word) {
            unparsed.append("\(word)不在可选器械里")
        }

        if result.isEmpty == false {
            return result
        }

        let bodyweightWords = ["没器械", "没有器械", "无器械", "徒手", "自重", "不去健身房", "不想去健身房", "家里只有垫子", "只有瑜伽垫"]
        if bodyweightWords.contains(where: { text.contains($0) }) {
            return [.bodyweight]
        }
        return nil
    }

    // MARK: - 目标与重点

    private static func parseGoal(_ text: String) -> PlanGoal? {
        if containsAny(["减脂", "减肥", "瘦", "掉秤"], in: text) { return .loseFat }
        if containsAny(["增肌", "长肌肉", "变壮"], in: text) { return .buildMuscle }
        if containsAny(["耐力", "心肺", "有氧", "跑步"], in: text) { return .endurance }
        if containsAny(["体能", "综合"], in: text) { return .generalFitness }
        if containsAny(["拉伸", "灵活", "柔韧", "放松", "瑜伽"], in: text) { return .mobility }
        return nil
    }

    private static func parseFocus(_ text: String, avoiding phrases: [String] = []) -> [String] {
        let text = masking(phrases, in: text)
        let groups: [(String, [String])] = [
            ("手臂", ["手臂", "胳膊", "肱二头", "肱三头", "拜拜肉"]),
            ("胸部", ["胸部", "胸肌", "胸"]),
            ("背部", ["背部", "背"]),
            ("肩部", ["肩部", "肩膀", "肩"]),
            ("腿部", ["腿部", "大腿", "小腿", "腿"]),
            ("臀部", ["臀部", "屁股", "臀"]),
            ("核心", ["核心", "腹部", "腹肌", "腹"]),
            ("全身", ["全身"])
        ]

        var hits: [(part: String, location: Int)] = []
        for (part, tokens) in groups {
            let locations = tokens.compactMap { firstLocation(of: $0, in: text) }
            if let location = locations.min() {
                hits.append((part, location))
            }
        }
        return hits.sorted { $0.location < $1.location }.map(\.part)
    }

    // MARK: - 避开

    private static func parseAvoid(_ text: String) -> [String] {
        var result: [String] = []

        let parts = BodyPart.avoidVocabulary.joined(separator: "|")
        let symptoms = "不舒服|不好|有伤|受伤|拉伤|发麻|弹响|咯噔|疼|痛|不适|酸|僵|麻"
        for groups in matches("((?:\(parts))(?:也|有点|有些|最近|一直|老是|总是|还)?\\s*(?:\(symptoms)))", in: text) {
            if let phrase = groups.first, phrase.isEmpty == false {
                result.append(phrase)
            }
        }

        for groups in matches("(?:不要|别|避免|不能|不想|做不了|不做)\\s*([^，。；,;\\s]{1,12})", in: text) {
            guard var phrase = groups.first, phrase.isEmpty == false else { continue }
            if phrase.hasPrefix("去") { continue }
            for suffix in ["的训练", "动作", "训练"] where phrase.hasSuffix(suffix) {
                phrase.removeLast(suffix.count)
            }
            if phrase.hasPrefix("做") { phrase.removeFirst() }
            if phrase == "跳" { phrase = "跳跃" }
            if phrase.isEmpty == false {
                result.append(phrase)
            }
        }

        return uniqued(result)
    }

    // MARK: - 工具

    private static func containsAny(_ words: [String], in text: String) -> Bool {
        words.contains { text.contains($0) }
    }

    private static func masking(_ phrases: [String], in text: String) -> String {
        guard phrases.isEmpty == false else { return text }
        let source = text as NSString
        var ranges: [NSRange] = []
        for phrase in phrases where phrase.isEmpty == false {
            var search = NSRange(location: 0, length: source.length)
            while search.length > 0 {
                let found = source.range(of: phrase, options: [], range: search)
                if found.location == NSNotFound { break }
                ranges.append(found)
                let next = found.location + max(1, found.length)
                search = NSRange(location: next, length: source.length - next)
            }
        }
        guard ranges.isEmpty == false else { return text }
        let buffer = NSMutableString(string: text)
        for range in ranges where NSMaxRange(range) <= buffer.length {
            buffer.replaceCharacters(in: range, with: String(repeating: " ", count: range.length))
        }
        return buffer as String
    }

    private static func firstLocation(of token: String, in text: String) -> Int? {
        let range = (text as NSString).range(of: token)
        return range.location == NSNotFound ? nil : range.location
    }
    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        matches(pattern, in: text).first?.first
    }

    private static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let source = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map { match in
            (1..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : source.substring(with: range)
            }
        }
    }

    private static func uniqued<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }
}
