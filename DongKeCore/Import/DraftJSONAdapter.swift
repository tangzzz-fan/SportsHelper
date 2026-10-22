import Foundation

public enum DraftJSONAdapter {
    private static let nameKeys = ["name", "exercise", "exercisename", "movement", "动作", "动作名", "名称"]
    private static let setsKeys = ["sets", "set", "组数", "组", "series"]
    private static let repsKeys = ["reps", "rep", "repetitions", "repetition", "次数", "次", "times"]
    private static let durationKeys = ["duration", "durationsec", "seconds", "secs", "hold", "second", "时长", "秒"]
    private static let minuteKeys = ["minutes", "minute", "mins", "min", "分钟", "分"]
    private static let restKeys = ["rest", "restsec", "restseconds", "resttime", "interval", "休息", "休息秒", "组间休息"]
    private static let restMinuteKeys = ["restminutes", "restmin", "休息分钟"]
    private static let perSideKeys = ["perside", "eachside", "unilateral", "每侧", "单侧"]
    private static let roundsKeys = ["rounds", "round", "循环", "轮次", "轮"]
    private static let dayKeys = ["day", "weekday", "date", "星期", "周几"]
    private static let dayLabelKeys = ["title", "name", "label", "focus", "dayname", "标题", "名称", "部位"]
    private static let dayContainerKeys = ["days", "day", "weeks", "week", "schedule", "训练日", "计划", "plan", "program", "split"]
    private static let notesKeys = ["notes", "note", "comment", "tip", "备注", "说明", "注意"]
    private static let titleKeys = ["title", "planname", "计划名", "计划名称", "name"]

    public static func draft(fromJSON text: String, memory: AliasMemory = .empty) -> PlanDraft? {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else { return nil }

        var days: [DraftDay] = []
        let containers = dayContainers(in: root)

        if containers.isEmpty {
            let items = collect(from: root, rounds: nil, memory: memory)
            guard !items.isEmpty else { return nil }
            days.append(DraftDay(order: 1, label: "训练", items: items))
        } else {
            for container in containers {
                let label = dayLabel(in: container) ?? "训练 \(days.count + 1)"
                let items = collect(from: container, rounds: nil, memory: memory)
                guard !items.isEmpty else { continue }
                days.append(DraftDay(
                    order: days.count + 1,
                    label: label,
                    weekday: DraftLineScanner.weekday(in: label),
                    rounds: roundsValue(in: container),
                    items: items
                ))
            }
        }

        guard days.isEmpty == false else { return nil }
        return PlanDraft(title: title(in: root), days: days, cautions: [], source: .genericJSON)
    }

    private static func dayContainers(in root: Any) -> [[String: Any]] {
        if let array = root as? [Any] {
            let dicts = array.compactMap { $0 as? [String: Any] }
            guard dicts.count == array.count, dicts.isEmpty == false else { return [] }
            let looksLikeDays = dicts.contains { dict in
                if value(in: dict, keys: dayKeys) != nil { return true }
                return dict.values.contains { element in
                    (element as? [Any])?.contains(where: { $0 is [String: Any] }) == true
                }
            }
            return looksLikeDays ? dicts : []
        }

        guard let dict = root as? [String: Any] else { return [] }
        let normalized = normalize(dict)

        for key in dayContainerKeys {
            guard let raw = normalized[normalizeKey(key)] else { continue }
            if let nested = raw as? [String: Any], let days = value(in: nested, keys: ["days"]) as? [Any] {
                return days.compactMap { $0 as? [String: Any] }
            }
            if let array = raw as? [Any] {
                let dicts = array.compactMap { $0 as? [String: Any] }
                guard dicts.count == array.count, dicts.isEmpty == false else { continue }
                if let weeks = dicts.first, let days = value(in: weeks, keys: ["days"]) as? [Any] {
                    return days.compactMap { $0 as? [String: Any] }
                }
                return dicts
            }
        }
        return []
    }

    private static func collect(from node: Any, rounds: Int?, memory: AliasMemory) -> [DraftItem] {
        var items: [DraftItem] = []
        walk(node, rounds: rounds, memory: memory, into: &items)
        return items
    }

    private static func walk(_ node: Any, rounds: Int?, memory: AliasMemory, into items: inout [DraftItem]) {
        if let array = node as? [Any] {
            for element in array { walk(element, rounds: rounds, memory: memory, into: &items) }
            return
        }
        guard let dict = node as? [String: Any] else { return }
        let normalized = normalize(dict)
        let localRounds = rounds ?? intValue(firstValue(in: normalized, keys: roundsKeys))

        if let name = nameValue(in: normalized), hasDose(normalized) {
            items.append(makeItem(normalized, name: name, rounds: localRounds, memory: memory))
            return
        }

        for value in dict.values {
            walk(value, rounds: localRounds, memory: memory, into: &items)
        }
    }

    private static func makeItem(_ dict: [String: Any], name: String, rounds: Int?, memory: AliasMemory) -> DraftItem {
        var assumptions: [String] = []
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let sets = intValue(firstValue(in: dict, keys: setsKeys))

        var value: Int?
        var targetType: SetTargetType?
        if let repsText = stringValue(firstValue(in: dict, keys: repsKeys)) {
            if let reps = firstInt(in: repsText) {
                value = reps
                targetType = .reps
                if repsText.contains("-") || repsText.contains("–") || repsText.contains("~") {
                    assumptions.append("写的是 \(repsText) 次，按 \(reps) 算")
                }
            }
        } else if let duration = intValue(firstValue(in: dict, keys: durationKeys)) {
            value = duration
            targetType = .durationSec
        } else if let minutes = intValue(firstValue(in: dict, keys: minuteKeys)) {
            value = minutes * 60
            targetType = .durationSec
        }

        var rest = intValue(firstValue(in: dict, keys: restKeys))
        if rest == nil, let minutes = intValue(firstValue(in: dict, keys: restMinuteKeys)) {
            rest = minutes * 60
        }

        let perSide = boolValue(firstValue(in: dict, keys: perSideKeys))
            ?? trimmedName.contains("每侧")

        if let rounds, rounds > 1, sets == nil {
            assumptions.append("这一项属于 \(rounds) 轮循环，组数按循环计算")
        }

        let hit = ExerciseAliasResolver.match(for: trimmedName, memory: memory)

        return DraftItem(
            rawName: trimmedName,
            catalogId: hit?.catalogId,
            sets: sets,
            value: value,
            targetType: targetType,
            perSide: perSide,
            restSec: rest,
            assumptions: assumptions,
            origin: trimmedName,
            reviewModifier: hit?.modifier,
            usedMemory: hit?.source == .memory
        )
    }

    private static func nameValue(in dict: [String: Any]) -> String? {
        for key in nameKeys {
            if let value = dict[normalizeKey(key)], let text = stringValue(value) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func hasDose(_ dict: [String: Any]) -> Bool {
        let keys = setsKeys + repsKeys + durationKeys + minuteKeys
        return keys.contains { dict[normalizeKey($0)] != nil }
    }

    private static func dayLabel(in dict: [String: Any]) -> String? {
        let normalized = normalize(dict)
        for key in dayKeys + dayLabelKeys {
            if let text = stringValue(normalized[normalizeKey(key)]) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func roundsValue(in dict: [String: Any]) -> Int? {
        let normalized = normalize(dict)
        guard let rounds = intValue(firstValue(in: normalized, keys: roundsKeys)), rounds > 1 else { return nil }
        return rounds
    }

    private static func title(in root: Any) -> String? {
        if let dict = root as? [String: Any] {
            let normalized = normalize(dict)
            if let meta = normalized[normalizeKey("meta")] as? [String: Any],
               let metaTitle = stringValue(firstValue(in: normalize(meta), keys: titleKeys)) {
                let trimmed = metaTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let text = stringValue(firstValue(in: normalized, keys: titleKeys)) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed.count <= 32 { return trimmed }
            }
        }
        return nil
    }

    private static func value(in dict: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dict[normalizeKey(key)] { return value }
        }
        return nil
    }

    private static func firstValue(in dict: [String: Any], keys: [String]) -> Any? {
        value(in: dict, keys: keys)
    }

    private static func normalize(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[normalizeKey(key)] = value
        }
        return result
    }

    private static func normalizeKey(_ key: String) -> String {
        key.lowercased().replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func stringValue(_ any: Any?) -> String? {
        guard let any else { return nil }
        if let text = any as? String { return text }
        if let number = any as? NSNumber { return number.stringValue }
        return nil
    }

    private static func intValue(_ any: Any?) -> Int? {
        guard let any else { return nil }
        if let number = any as? NSNumber { return number.intValue }
        if let text = any as? String { return firstInt(in: text) }
        return nil
    }

    private static func boolValue(_ any: Any?) -> Bool? {
        guard let any else { return nil }
        if let number = any as? NSNumber { return number.boolValue }
        if let text = any as? String {
            let lowered = text.lowercased()
            if ["true", "yes", "1", "是"].contains(lowered) { return true }
            if ["false", "no", "0", "否"].contains(lowered) { return false }
        }
        return nil
    }

    private static func firstInt(in text: String) -> Int? {
        guard let match = DraftLineScanner.firstMatch(in: text, pattern: "[0-9]+") else { return nil }
        return Int(text[match.range])
    }
}
