import Foundation

public enum FreeTextPlanParser {
    private struct DraftItem {
        var name: String
        var sets: Int
        var target: SetTarget
        var restSec: Int
    }

    private struct DayBucket {
        var rounds: Int = 1
        var items: [DraftItem] = []
    }

    private static let catalogPairs: [(name: String, id: String)] = [
        ("靠墙静蹲", "wall_sit"),
        ("俄罗斯转体", "russian_twist"),
        ("侧平板支撑", "side_plank"),
        ("平板支撑", "plank"),
        ("登山跑", "mountain_climber"),
        ("高抬腿", "high_knees"),
        ("开合跳", "jumping_jack"),
        ("俯卧撑", "push_up"),
        ("弓步蹲", "lunge"),
        ("箭步蹲", "lunge"),
        ("臀桥", "glute_bridge"),
        ("哑铃划船", "dumbbell_row"),
        ("肩推", "shoulder_press"),
        ("死虫", "dead_bug"),
        ("提踵", "calf_raise"),
        ("鸟狗", "bird_dog"),
        ("超人", "superman"),
        ("卷腹", "crunch"),
        ("深蹲", "squat")
    ]

    public static func parse(_ text: String) -> ParsedPlanDraft {
        var buckets: [Int: DayBucket] = [:]
        var currentDay: Int?

        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let day = weekdayIndex(in: line) {
                currentDay = day
                line = removingWeekdayToken(in: line)
                if buckets[day] == nil { buckets[day] = DayBucket() }
            }
            guard let day = currentDay else { continue }
            if buckets[day] == nil { buckets[day] = DayBucket() }

            if let match = firstMatch(in: line, pattern: "循环\\s*(\\d+)\\s*轮") {
                buckets[day]?.rounds = max(1, Int(match.groups.first ?? "") ?? 1)
                line.removeSubrange(match.range)
            }

            if let item = parseItem(line) {
                buckets[day]?.items.append(item)
            }
        }

        guard buckets.values.contains(where: { !$0.items.isEmpty }) else {
            return ParsedPlanDraft.empty(rawText: text)
        }

        var days: [PlanDay] = []
        for index in 1...7 {
            guard let weekday = Weekday(rawValue: index) else { continue }
            let bucket = buckets[index]
            let items = bucket?.items ?? []

            guard !items.isEmpty else {
                days.append(PlanDay(
                    dayIndex: index,
                    weekday: weekday,
                    isRestDay: true,
                    title: "休息",
                    scheduledTime: nil,
                    estimatedMinutes: 0,
                    blocks: [],
                    notes: ""
                ))
                continue
            }

            let rounds = max(1, bucket?.rounds ?? 1)
            let isCircuit = rounds > 1
            let prescriptions = items.enumerated().map { offset, item in
                ExercisePrescription(
                    itemId: "i\(offset + 1)",
                    catalogId: catalogId(for: item.name),
                    name: item.name,
                    sets: item.sets,
                    target: item.target,
                    restSec: item.restSec
                )
            }
            let block = ExerciseBlock(
                blockId: "b1",
                kind: isCircuit ? .circuit : .main,
                title: isCircuit ? "循环训练" : "主训练",
                rounds: rounds,
                restBetweenItemsSec: 0,
                restBetweenRoundsSec: isCircuit ? 60 : 0,
                items: prescriptions
            )
            let totalSets = prescriptions.reduce(0) { $0 + $1.sets * rounds }
            days.append(PlanDay(
                dayIndex: index,
                weekday: weekday,
                isRestDay: false,
                title: "训练",
                scheduledTime: nil,
                estimatedMinutes: max(5, totalSets * 2),
                blocks: [block],
                notes: ""
            ))
        }

        let trainingDays = days.filter { !$0.isRestDay }
        let sessionMinutes = min(120, max(5, trainingDays.map(\.estimatedMinutes).max() ?? 30))
        let plan = WorkoutPlan(
            meta: PlanMeta(
                title: planTitle(from: text),
                goal: .loseFat,
                level: .beginner,
                daysPerWeek: trainingDays.count,
                sessionMinutes: sessionMinutes
            ),
            days: days,
            cautions: ["关节疼痛须停训，动作幅度以无痛为限"],
            source: .pasteText
        )

        return ParsedPlanDraft(
            plan: plan,
            issues: PlanValidator.validate(plan),
            rawText: text,
            path: .freeText
        )
    }

    private static func parseItem(_ raw: String) -> DraftItem? {
        var working = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        var sets = 0
        var reps = 0
        var seconds = 0
        var rest = 60
        let perSide = working.contains("每侧")

        if let match = firstMatch(in: working, pattern: "休息\\s*(\\d+)\\s*(分钟|min|秒|s)") {
            let amount = Int(match.groups[0]) ?? 0
            let unit = match.groups.count > 1 ? match.groups[1] : ""
            rest = (unit == "分钟" || unit == "min") ? amount * 60 : amount
            working.removeSubrange(match.range)
        }

        if let match = firstMatch(in: working, pattern: "(\\d+)\\s*组?\\s*[×xX*]\\s*(\\d+)\\s*(次|秒)?") {
            sets = Int(match.groups[0]) ?? 0
            let unit = match.groups.count > 2 ? match.groups[2] : ""
            if unit == "秒" {
                seconds = Int(match.groups[1]) ?? 0
            } else {
                reps = Int(match.groups[1]) ?? 0
            }
            working.removeSubrange(match.range)
        }

        if sets == 0, let match = firstMatch(in: working, pattern: "(\\d+)\\s*组") {
            sets = Int(match.groups[0]) ?? 0
            working.removeSubrange(match.range)
        }

        if reps == 0, seconds == 0, let match = firstMatch(in: working, pattern: "(\\d+)\\s*次") {
            reps = Int(match.groups[0]) ?? 0
            working.removeSubrange(match.range)
        }

        if seconds == 0, let match = firstMatch(in: working, pattern: "(\\d+)\\s*秒") {
            seconds = Int(match.groups[0]) ?? 0
            working.removeSubrange(match.range)
        }

        let name = cleanedName(working)
        guard !name.isEmpty, sets > 0 || reps > 0 || seconds > 0 else { return nil }

        let target: SetTarget = seconds > 0
            ? SetTarget(type: .durationSec, value: seconds, perSide: perSide)
            : SetTarget(type: .reps, value: max(1, reps), perSide: perSide)

        return DraftItem(name: name, sets: max(1, sets), target: target, restSec: max(0, rest))
    }

    private static func cleanedName(_ raw: String) -> String {
        let noise = [
            "每组", "每侧", "循环", "休息", "分钟", "组", "次", "秒",
            "×", "x", "X", "*", "，", ",", "、", "；", ";", "：", ":", "。",
            "（", "）", "(", ")", "-", "—", " "
        ]
        var result = raw
        for token in noise {
            result = result.replacingOccurrences(of: token, with: " ")
        }
        result = result.replacingOccurrences(of: "[0-9]+", with: " ", options: .regularExpression)
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains(where: { $0.isLetter }) else { return "" }
        return trimmed
    }

    private static func catalogId(for name: String) -> String {
        for pair in catalogPairs where name.contains(pair.name) {
            return pair.id
        }
        return "custom_\(name)"
    }

    private static func planTitle(from text: String) -> String {
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let withoutWeekday = removingWeekdayToken(in: line)
            if parseItem(withoutWeekday) != nil { continue }
            if line.rangeOfCharacter(from: .decimalDigits) != nil { continue }
            let stripped = cleanedName(withoutWeekday)
            if stripped.count >= 2 {
                return String(stripped.prefix(24))
            }
        }
        return "我的训练计划"
    }

    private static func weekdayIndex(in line: String) -> Int? {
        guard let match = firstMatch(in: line, pattern: "(周|星期|礼拜)([一二三四五六日天])") else {
            return nil
        }
        switch match.groups[1] {
        case "一": return 1
        case "二": return 2
        case "三": return 3
        case "四": return 4
        case "五": return 5
        case "六": return 6
        default: return 7
        }
    }

    private static func removingWeekdayToken(in line: String) -> String {
        guard let match = firstMatch(in: line, pattern: "(周|星期|礼拜)([一二三四五六日天])") else {
            return line
        }
        var result = line
        result.removeSubrange(match.range)
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func firstMatch(
        in text: String,
        pattern: String
    ) -> (groups: [String], range: Range<String.Index>)? {
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
