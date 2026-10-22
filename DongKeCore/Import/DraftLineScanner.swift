import Foundation

public enum DraftLineScanner {
    private static let unitTokens = [
        "每分钟", "分钟", "每组", "每侧", "单侧", "循环", "休息", "间隔", "组间",
        "轮次", "组", "次", "秒", "轮", "共", "第", "公里", "米"
    ]

    private static let latinUnits = [
        "sets", "set", "reps", "rep", "repetitions", "repetition", "rounds", "round",
        "seconds", "second", "secs", "sec", "minutes", "minute", "mins", "min",
        "times", "each", "side", "per"
    ]

    private static let fillers = [
        "然后", "接着", "之后", "最后", "再做", "先做", "交替", "左右", "一下", "随便", "做"
    ]

    private static let dayKeywords = [
        "训练", "休息", "上肢", "下肢", "全身", "核心", "推", "拉", "腿", "胸", "背", "肩", "有氧"
    ]

    private static let cautionPrefixes = ["注意", "提示", "建议", "备注", "说明", "⚠"]

    public static func scan(_ text: String, memory: AliasMemory = .empty) -> PlanDraft? {
        var days: [DraftDay] = []
        var title: String?
        var cautions: [String] = []

        func openDay(label: String, weekday: Weekday?) {
            days.append(DraftDay(order: days.count + 1, label: label.isEmpty ? "训练" : label, weekday: weekday))
        }

        func append(_ items: [DraftItem]) {
            guard !items.isEmpty else { return }
            if days.isEmpty { openDay(label: "训练", weekday: nil) }
            days[days.count - 1].items.append(contentsOf: items)
        }

        for rawLine in expandingDayMarkers(text).components(separatedBy: .newlines) {
            let line = stripDecoration(rawLine)
            guard !line.isEmpty, !isSeparator(line) else { continue }

            if cautionPrefixes.contains(where: { line.hasPrefix($0) }) {
                cautions.append(line)
                continue
            }

            if let weekday = weekday(in: line) {
                var remainder = removingWeekdayToken(in: line)
                let rounds = takeRounds(in: &remainder)
                let parsed = items(from: remainder, memory: memory)
                openDay(label: parsed.isEmpty ? labelText(from: line) : "", weekday: weekday)
                days[days.count - 1].rounds = rounds
                append(parsed)
                continue
            }

            if !days.isEmpty {
                var remainder = line
                if let rounds = takeRounds(in: &remainder) {
                    days[days.count - 1].rounds = rounds
                    append(items(from: remainder, memory: memory))
                    continue
                }
            }

            if days.isEmpty {
                if looksLikeDayLabel(line) {
                    openDay(label: cleanedName(line), weekday: nil)
                    continue
                }
                if looksLikeTitle(line) {
                    title = cleanedName(line)
                    continue
                }
                append(items(from: line, memory: memory))
                continue
            }

            if looksLikeDayLabel(line), hasDose(line) == false {
                openDay(label: cleanedName(line), weekday: nil)
                continue
            }

            append(items(from: line, memory: memory))
        }

        guard days.contains(where: { !$0.items.isEmpty }) else { return nil }
        return PlanDraft(title: title, days: days, cautions: cautions, source: .lineScan)
    }

    static func items(from line: String, memory: AliasMemory = .empty) -> [DraftItem] {
        let matches = aliasMatches(in: line)
        guard matches.count >= 2 else {
            return parseItem(line, forcedId: matches.first?.id, memory: memory).map { [$0] } ?? []
        }

        var result: [DraftItem] = []
        for (index, match) in matches.enumerated() {
            var start = match.range.lowerBound
            let end = index + 1 < matches.count ? matches[index + 1].range.lowerBound : line.endIndex
            if index == 0, let head = trailingModifierStart(in: line[line.startIndex..<start]) {
                start = head
            }
            guard start < end else { continue }
            if let item = parseItem(String(line[start..<end]), forcedId: match.id, memory: memory) {
                result.append(item)
            }
        }
        return result
    }

    private static func trailingModifierStart(in head: Substring) -> String.Index? {
        var best: String.Index?
        for modifier in ExerciseAliasResolver.modifiers where head.hasSuffix(modifier) {
            let candidate = head.index(head.endIndex, offsetBy: -modifier.count)
            if best == nil || candidate < best! { best = candidate }
        }
        return best
    }

    static func parseItem(_ raw: String, forcedId: String? = nil, memory: AliasMemory = .empty) -> DraftItem? {
        var working = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        var assumptions: [String] = []
        var sets: Int?
        var value: Int?
        var targetType: SetTargetType?
        var rest: Int?
        let perSide = containsAny(working.lowercased(), ["每侧", "单侧", "each side", "per side", "each leg", "单腿"])
        let origin = working

        if let match = firstMatch(in: working, pattern: "(?:休息|组间|间隔|rest)\\s*[:：]?\\s*(\\d+)\\s*(分钟|min|分|秒|s|sec)?") {
            let amount = Int(match.groups[0]) ?? 0
            let unit = match.groups.count > 1 ? match.groups[1].lowercased() : ""
            rest = (unit == "分钟" || unit == "min" || unit == "分") ? amount * 60 : amount
            working.removeSubrange(match.range)
        }

        if let match = firstMatch(in: working, pattern: "(\\d+)\\s*[-–~到至]\\s*(\\d+)\\s*(次|reps?|秒|s)?") {
            let lower = Int(match.groups[0]) ?? 0
            let upper = Int(match.groups[1]) ?? lower
            let unit = match.groups.count > 2 ? match.groups[2].lowercased() : ""
            value = lower
            targetType = (unit == "秒" || unit == "s") ? .durationSec : .reps
            assumptions.append("写的是 \(lower)–\(upper) \(unit.isEmpty ? "次" : unit)，按 \(lower) 算")
            working.removeSubrange(match.range)
        }

        if value == nil,
           let match = firstMatch(in: working, pattern: "(\\d+)\\s*(?:组|sets?)?\\s*[×xX*]\\s*(\\d+)\\s*(次|秒|reps?|s)?"),
           let parsedSets = Int(match.groups[0]) {
            sets = parsedSets
            value = Int(match.groups[1])
            let unit = match.groups.count > 2 ? match.groups[2].lowercased() : ""
            targetType = (unit == "秒" || unit == "s") ? .durationSec : .reps
            working.removeSubrange(match.range)
        }

        if sets == nil, let match = firstMatch(in: working, pattern: "(\\d+)\\s*(?:组|sets?|series)"), let parsed = Int(match.groups[0]) {
            sets = parsed
            working.removeSubrange(match.range)
        }

        if value == nil, let match = firstMatch(in: working, pattern: "(\\d+)\\s*(?:次|reps?|repetitions?)"), let parsed = Int(match.groups[0]) {
            value = parsed
            targetType = .reps
            working.removeSubrange(match.range)
        }

        if value == nil, let match = firstMatch(in: working, pattern: "(\\d+)\\s*(?:秒|s\\b|sec|seconds?)"), let parsed = Int(match.groups[0]) {
            value = parsed
            targetType = .durationSec
            working.removeSubrange(match.range)
        }

        if value == nil, let match = firstMatch(in: working, pattern: "(\\d+)\\s*(?:分钟|min)"), let parsed = Int(match.groups[0]) {
            value = parsed * 60
            targetType = .durationSec
            working.removeSubrange(match.range)
        }

        let name = cleanedName(working)
        guard !name.isEmpty else { return nil }

        let hit = ExerciseAliasResolver.match(for: name, memory: memory)
        let usedMemory = hit?.source == .memory
        let resolved = usedMemory ? hit?.catalogId : (forcedId ?? hit?.catalogId)
        let reviewModifier = forcedId == nil || hit?.catalogId == forcedId ? hit?.modifier : nil
        let hasDose = sets != nil || value != nil

        guard hasDose || resolved != nil else { return nil }

        if let catalog = resolved, let entry = ExerciseLibrary.entry(for: catalog) {
            if value == nil, entry.isStatic {
                assumptions.append("「\(entry.name)」没写时长，按 30 秒")
            }
            if reviewModifier == nil, !usedMemory,
               ExerciseAliasResolver.normalize(name).contains(ExerciseAliasResolver.normalize(entry.name)) == false {
                assumptions.append("「\(name)」按「\(entry.name)」处理")
            }
        }

        return DraftItem(
            rawName: name,
            catalogId: resolved,
            sets: sets,
            value: value,
            targetType: targetType,
            perSide: perSide,
            restSec: rest,
            assumptions: assumptions,
            origin: origin,
            reviewModifier: reviewModifier,
            usedMemory: usedMemory
        )
    }

    static func cleanedName(_ raw: String) -> String {
        var result = raw
        result = result.replacingOccurrences(
            of: "(?i)\\d+\\s*(kg|kgs|lbs?|pounds?|公斤|千克|磅)",
            with: " ",
            options: .regularExpression
        )
        for token in unitTokens {
            result = result.replacingOccurrences(of: token, with: " ")
        }
        for token in latinUnits {
            result = result.replacingOccurrences(
                of: "\\b\(token)\\b",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        for token in fillers {
            result = result.replacingOccurrences(of: token, with: " ")
        }
        result = result.replacingOccurrences(of: "[0-9]+", with: " ", options: .regularExpression)
        let punctuation = CharacterSet(charactersIn: "×xX*·—–-_,，、;；:：。.()（）[]【】<>《》\"'`#｜|/\\+~!?！？@$%^&=")
        result = String(result.unicodeScalars.map { punctuation.contains($0) || $0 == " " ? " " : String($0) }.joined())
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func weekday(in line: String) -> Weekday? {
        if let match = firstMatch(in: line, pattern: "(周|星期|礼拜)([一二三四五六日天])") {
            switch match.groups[1] {
            case "一": return .monday
            case "二": return .tuesday
            case "三": return .wednesday
            case "四": return .thursday
            case "五": return .friday
            case "六": return .saturday
            default: return .sunday
            }
        }
        if let match = firstMatch(
            in: line,
            pattern: "(?i)\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tues|tue|wed|thurs|thur|thu|fri|sat|sun)\\b"
        ) {
            let token = match.groups[0].lowercased()
            for day in Weekday.allCases where day.englishName.hasPrefix(String(token.prefix(3))) {
                return day
            }
        }
        if let match = firstMatch(in: line, pattern: "(?i)(?:day|第)\\s*([1-7])"), let raw = Int(match.groups[0]) {
            return Weekday(rawValue: raw)
        }
        return nil
    }

    static func removingWeekdayToken(in line: String) -> String {
        var result = line
        if let match = firstMatch(in: result, pattern: "(周|星期|礼拜)([一二三四五六日天])") {
            result.removeSubrange(match.range)
        } else if let match = firstMatch(in: result, pattern: "(?i)\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\\b") {
            result.removeSubrange(match.range)
        } else if let match = firstMatch(in: result, pattern: "(?i)(?:day|第)\\s*[1-7]\\s*天?") {
            result.removeSubrange(match.range)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func labelText(from line: String) -> String {
        let rest = cleanedName(removingWeekdayToken(in: line))
        return rest.isEmpty ? "训练" : rest
    }

    static func roundsOnly(in line: String) -> Int? {
        var working = line
        return takeRounds(in: &working)
    }

    @discardableResult
    static func takeRounds(in line: inout String) -> Int? {
        let patterns = [
            "循环\\s*(\\d+)\\s*轮",
            "(\\d+)\\s*轮",
            "(?i)(\\d+)\\s*rounds?",
            "(?i)circuit\\s*[x×]?\\s*(\\d+)"
        ]
        for pattern in patterns {
            if let match = firstMatch(in: line, pattern: pattern), let rounds = Int(match.groups[0]) {
                line.removeSubrange(match.range)
                return rounds
            }
        }
        return nil
    }

    static func looksLikeDayLabel(_ line: String) -> Bool {
        guard hasDose(line) == false else { return false }
        guard line.count <= 12 else { return false }
        guard !containsAny(line, ["，", "。", "；", ",", ";", "："]) else { return false }
        if line.hasSuffix("日") || line.hasSuffix("天") { return true }
        return dayKeywords.contains { line.contains($0) }
    }

    static func looksLikeTitle(_ line: String) -> Bool {
        guard line.count >= 2, line.count <= 24 else { return false }
        guard hasDose(line) == false else { return false }
        guard line.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        guard ExerciseAliasResolver.catalogId(for: line) == nil else { return false }
        return !containsAny(line, ["，", "。", "；", ",", ";"])
    }

    static func hasDose(_ line: String) -> Bool {
        firstMatch(in: line, pattern: "[0-9]+\\s*(组|次|秒|分钟|轮|sets?|reps?|rounds?|s\\b|min)") != nil
            || firstMatch(in: line, pattern: "[0-9]+\\s*[×xX*]\\s*[0-9]+") != nil
    }

    static func expandingDayMarkers(_ text: String) -> String {
        var output: [String] = []
        for line in text.components(separatedBy: .newlines) {
            for part in splitAtDayMarkers(line) {
                output.append(contentsOf: splitSentences(part))
            }
        }
        return output.joined(separator: "\n")
    }

    private static func splitAtDayMarkers(_ line: String) -> [String] {
        let pattern = "(周|星期|礼拜)[一二三四五六日天]|(?i:\\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b)|(?i:\\bday\\s*[1-7]\\b)|第\\s*[1-7]\\s*天"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [line] }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        guard matches.count > 1 || (matches.count == 1 && matches[0].range.location > 0) else {
            return [line]
        }

        var parts: [String] = []
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                let head = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                    .trimmingCharacters(in: .whitespaces)
                if !head.isEmpty { parts.append(head) }
            }
            cursor = match.range.location
        }
        let tail = ns.substring(from: cursor).trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { parts.append(tail) }
        return parts.isEmpty ? [line] : parts
    }

    private static func splitSentences(_ part: String) -> [String] {
        part.components(separatedBy: CharacterSet(charactersIn: "。；;！!？?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func stripDecoration(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespaces)
        line = line.replacingOccurrences(of: "\\*\\*|__|`|^#{1,6}\\s*|^>\\s*", with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: "^[-*•·]\\s+|^\\d+[.)]\\s+", with: "", options: .regularExpression)
        return line.trimmingCharacters(in: .whitespaces)
    }

    private static func isSeparator(_ line: String) -> Bool {
        line.allSatisfy { "-=_—  ".contains($0) }
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private struct AliasMatch {
        var range: Range<String.Index>
        var id: String
        var length: Int
    }

    private static func aliasMatches(in line: String) -> [AliasMatch] {
        var found: [AliasMatch] = []
        for (alias, id) in ExerciseAliasResolver.aliases {
            var searchStart = line.startIndex
            while searchStart < line.endIndex,
                  let range = line.range(of: alias, options: [.caseInsensitive], range: searchStart..<line.endIndex) {
                found.append(AliasMatch(range: range, id: id, length: line.distance(from: range.lowerBound, to: range.upperBound)))
                searchStart = range.upperBound
            }
        }
        let sorted = found.sorted { $0.length > $1.length }
        var accepted: [AliasMatch] = []
        for candidate in sorted {
            let overlaps = accepted.contains { $0.range.overlaps(candidate.range) }
            if !overlaps { accepted.append(candidate) }
        }
        return accepted.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    static func firstMatch(in text: String, pattern: String) -> (groups: [String], range: Range<String.Index>)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        var groups: [String] = []
        if match.numberOfRanges > 1 {
            for index in 1..<match.numberOfRanges {
                let range = match.range(at: index)
                groups.append(range.location == NSNotFound ? "" : nsText.substring(with: range))
            }
        }
        guard let range = Range(match.range, in: text) else { return nil }
        return (groups, range)
    }
}
