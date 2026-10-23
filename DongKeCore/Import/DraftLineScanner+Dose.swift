import Foundation

extension DraftLineScanner {
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
           let match = firstMatch(in: working, pattern: "(?i)(\\d+(?:\\.\\d+)?)\\s*(公里|千米|km|米|meters?|m\\b)"),
           let amount = Double(match.groups[0]) {
            let unit = match.groups[1].lowercased()
            let meters = (unit == "公里" || unit == "千米" || unit == "km") ? amount * 1000 : amount
            value = Int(meters.rounded())
            targetType = .distanceM
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
}
