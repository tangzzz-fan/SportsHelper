import Foundation

extension DraftLineScanner {
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
        if let match = firstMatch(in: line, pattern: "(?i)\\bday\\s*([1-7])"), let raw = Int(match.groups[0]) {
            return Weekday(rawValue: raw)
        }
        if let match = firstMatch(in: line, pattern: "第\\s*([1-7])\\s*[天日]"), let raw = Int(match.groups[0]) {
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
        } else if let match = firstMatch(in: result, pattern: "(?i)(?:day\\s*[1-7]|第\\s*[1-7]\\s*[天日])") {
            result.removeSubrange(match.range)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func labelText(from line: String) -> String {
        let rest = cleanedName(removingWeekdayToken(in: line))
        return rest.isEmpty ? "训练" : rest
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

    static func splitAtDayMarkers(_ line: String) -> [String] {
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

    static func splitSentences(_ part: String) -> [String] {
        part.components(separatedBy: CharacterSet(charactersIn: "。；;！!？?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func stripDecoration(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespaces)
        line = line.replacingOccurrences(of: "\\*\\*|__|`|^#{1,6}\\s*|^>\\s*", with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: "^[-*•·]\\s+|^\\d+[.)]\\s+", with: "", options: .regularExpression)
        return line.trimmingCharacters(in: .whitespaces)
    }

    static func isSeparator(_ line: String) -> Bool {
        line.allSatisfy { "-=_—  ".contains($0) }
    }
}
