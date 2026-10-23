import Foundation

extension DraftLineScanner {
    static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    struct AliasMatch {
        var range: Range<String.Index>
        var id: String
        var length: Int
    }

    static func aliasMatches(in line: String) -> [AliasMatch] {
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
