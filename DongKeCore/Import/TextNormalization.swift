import Foundation

enum TextNormalization {
    static func normalize(_ text: String) -> String {
        chineseNumerals(halfWidthDigits(text))
    }

    static func halfWidthDigits(_ text: String) -> String {
        var result = ""
        for character in text {
            let scalars = character.unicodeScalars
            if scalars.count == 1,
               let scalar = scalars.first,
               scalar.value >= 0xFF10,
               scalar.value <= 0xFF19,
               let ascii = UnicodeScalar(scalar.value - 0xFF10 + 0x30) {
                result.append(Character(ascii))
            } else {
                result.append(character)
            }
        }
        return result
    }

    static func chineseNumerals(_ text: String) -> String {
        let pattern = "([一二三四五六七八九十两]{1,3})(\\s*)(组|轮|次|秒|分钟|分)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let source = text as NSString
        var result = ""
        var cursor = 0

        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            let token = source.substring(with: match.range(at: 1))
            guard let value = number(of: token) else { continue }
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += "\(value)\(source.substring(with: match.range(at: 2)))\(source.substring(with: match.range(at: 3)))"
            cursor = match.range.location + match.range.length
        }

        result += source.substring(from: cursor)
        return result
    }

    static func number(of token: String) -> Int? {
        let digits: [Character: Int] = [
            "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]

        guard token.contains("十") else {
            guard token.count == 1, let first = token.first else { return nil }
            return digits[first]
        }

        let parts = token.split(separator: "十", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count <= 1, parts[1].count <= 1 else { return nil }
        let tens = parts[0].isEmpty ? 1 : parts[0].first.flatMap { digits[$0] }
        let ones = parts[1].isEmpty ? 0 : parts[1].first.flatMap { digits[$0] }
        guard let tens, let ones else { return nil }
        return tens * 10 + ones
    }
}
