import Foundation

public enum DraftLineScanner {
    static let unitTokens = [
        "每分钟", "分钟", "每组", "每侧", "单侧", "循环", "休息", "间隔", "组间",
        "轮次", "组", "次", "秒", "轮", "共", "第", "公里", "米"
    ]

    static let latinUnits = [
        "sets", "set", "reps", "rep", "repetitions", "repetition", "rounds", "round",
        "seconds", "second", "secs", "sec", "minutes", "minute", "mins", "min",
        "times", "each", "side", "per"
    ]

    static let fillers = [
        "然后", "接着", "之后", "最后", "再做", "先做", "交替", "左右", "一下", "随便", "做"
    ]

    static let dayKeywords = [
        "训练", "休息", "上肢", "下肢", "全身", "核心", "推", "拉", "腿", "胸", "背", "肩", "有氧"
    ]

    static let cautionPrefixes = ["注意", "提示", "建议", "备注", "说明", "⚠"]

    public static func scan(_ text: String, memory: AliasMemory = .empty) -> PlanDraft? {
        var days: [DraftDay] = []
        var title: String?
        var cautions: [String] = []
        var notes: [String] = []

        var lines = expandingDayMarkers(text).components(separatedBy: .newlines)
        let firstContent = lines.firstIndex {
            !stripDecoration($0).trimmingCharacters(in: .whitespaces).isEmpty
        } ?? 0
        if let boundary = lines.indices.first(where: {
            $0 > firstContent && (weekNumber(in: lines[$0]) ?? 1) >= 2
        }) {
            lines = Array(lines[..<boundary])
            notes.append("这段内容含多周安排，已只保留第 1 周")
        }

        func openDay(label: String, weekday: Weekday?) {
            days.append(DraftDay(order: days.count + 1, label: label.isEmpty ? "训练" : label, weekday: weekday))
        }

        func append(_ items: [DraftItem]) {
            guard !items.isEmpty else { return }
            if days.isEmpty { openDay(label: "训练", weekday: nil) }
            days[days.count - 1].items.append(contentsOf: items)
        }

        for rawLine in lines {
            let line = stripDecoration(rawLine)
            guard !line.isEmpty, !isSeparator(line) else { continue }

            if weekNumber(in: line) != nil { continue }

            if cautionPrefixes.contains(where: { line.hasPrefix($0) }) {
                cautions.append(line)
                continue
            }

            if outOfRangeDay(in: line) {
                openDay(label: "训练", weekday: nil)
                append(items(from: removingOutOfRangeDayToken(in: line), memory: memory))
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
                    title = title ?? line
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
        return PlanDraft(title: title, days: days, cautions: cautions, notes: notes, source: .lineScan)
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

}
