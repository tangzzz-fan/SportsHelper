import Foundation

public enum DraftTableAdapter {
    public static func draft(from text: String, memory: AliasMemory = .empty) -> PlanDraft? {
        var title: String?
        var days: [DraftDay] = []
        var header: [String]?
        var weekdayColumn: Int?
        var themeColumn: Int?
        var fallbackDayIndex: Int?
        var pendingWeekday: Weekday?
        var pendingLabel: String?

        let lines = text.components(separatedBy: .newlines)

        for (offset, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("|") {
                let cells = splitRow(line)
                guard !cells.isEmpty else { continue }
                if isDivider(cells) { continue }

                if header == nil {
                    header = cells
                    weekdayColumn = column(in: cells, keys: ["星期", "周几", "weekday", "day", "日期"])
                    themeColumn = column(in: cells, keys: ["主题", "部位", "title", "focus"])
                    continue
                }
                guard let header, let item = makeItem(cells: cells, header: header, memory: memory) else { continue }

                if let weekday = rowWeekday(cells: cells, column: weekdayColumn) {
                    if let index = days.firstIndex(where: { $0.weekday == weekday }) {
                        days[index].items.append(item)
                    } else {
                        days.append(DraftDay(
                            order: days.count + 1,
                            label: rowTheme(cells: cells, column: themeColumn) ?? "训练",
                            weekday: weekday
                        ))
                        days[days.count - 1].items.append(item)
                    }
                    continue
                }

                if fallbackDayIndex == nil {
                    days.append(DraftDay(
                        order: days.count + 1,
                        label: pendingLabel ?? "训练",
                        weekday: pendingWeekday
                    ))
                    fallbackDayIndex = days.count - 1
                }
                days[fallbackDayIndex!].items.append(item)
                continue
            }

            header = nil
            weekdayColumn = nil
            themeColumn = nil
            fallbackDayIndex = nil

            if let weekday = DraftLineScanner.weekday(in: line) {
                pendingWeekday = weekday
                let remainder = DraftLineScanner.removingWeekdayToken(in: line)
                let label = DraftLineScanner.cleanedName(remainder)
                pendingLabel = label.isEmpty ? weekday.chineseName : label
                continue
            }

            if let label = headingLabel(from: line) {
                if nextContentIsTable(lines, after: offset) {
                    if title == nil { title = label }
                } else {
                    pendingWeekday = nil
                    pendingLabel = label
                }
                continue
            }

            if title == nil, DraftLineScanner.looksLikeTitle(line) {
                title = DraftLineScanner.cleanedName(line)
            }
        }

        guard days.contains(where: { !$0.items.isEmpty }) else { return nil }
        return PlanDraft(title: title, days: days, cautions: [], notes: [], source: .markdownTable)
    }

    private static func splitRow(_ line: String) -> [String] {
        var body = line
        if body.hasPrefix("|") { body.removeFirst() }
        if body.hasSuffix("|") { body.removeLast() }
        return body.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isDivider(_ cells: [String]) -> Bool {
        cells.allSatisfy { cell in
            !cell.isEmpty && cell.allSatisfy { "-: —".contains($0) }
        }
    }

    private static func rowWeekday(cells: [String], column: Int?) -> Weekday? {
        guard let column, cells.indices.contains(column) else { return nil }
        let text = cells[column].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        if let weekday = DraftLineScanner.weekday(in: text) { return weekday }
        if let number = Int(text), (1...7).contains(number) {
            return Weekday(rawValue: number)
        }
        let single: [String: Weekday] = [
            "一": .monday, "二": .tuesday, "三": .wednesday, "四": .thursday,
            "五": .friday, "六": .saturday, "日": .sunday, "天": .sunday
        ]
        return single[text]
    }

    private static func rowTheme(cells: [String], column: Int?) -> String? {
        guard let column, cells.indices.contains(column) else { return nil }
        let value = DraftLineScanner.cleanedName(cells[column])
        return value.isEmpty ? nil : value
    }

    private static func nextContentIsTable(_ lines: [String], after index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        for offset in (index + 1)..<lines.count {
            let line = lines[offset].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            return line.hasPrefix("|")
        }
        return false
    }

    private static func headingLabel(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let label = DraftLineScanner.cleanedName(trimmed)
        return label.isEmpty ? nil : label
    }

    private static func makeItem(cells: [String], header: [String], memory: AliasMemory) -> DraftItem? {
        let nameIndex = column(in: header, keys: ["动作", "exercise", "movement", "名称", "训练"])
        let setsIndex = column(in: header, keys: ["组数", "set", "series", "组"])
        let repsIndex = column(in: header, keys: ["次数", "rep", "repetition", "times", "次"])
        let durationIndex = column(in: header, keys: ["秒", "时长", "duration", "hold", "sec", "time"])
        let restIndex = column(in: header, keys: ["休息", "rest", "interval", "间隔"])

        let fallbackNameIndex = nameIndex ?? header.indices.first { index in
            cells.indices.contains(index) && cells[index].isEmpty == false && Int(cells[index]) == nil
        }
        guard let nameColumn = fallbackNameIndex, cells.indices.contains(nameColumn) else { return nil }

        let rawName = DraftLineScanner.cleanedName(cells[nameColumn])
        guard !rawName.isEmpty else { return nil }

        func cell(_ index: Int?) -> String? {
            guard let index, cells.indices.contains(index) else { return nil }
            let value = cells[index].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        var assumptions: [String] = []
        let sets = cell(setsIndex).flatMap { number(in: $0) }

        var value: Int?
        var targetType: SetTargetType?
        if let repsText = cell(repsIndex), let reps = number(in: repsText) {
            value = reps
            targetType = .reps
            if repsText.contains("-") || repsText.contains("–") || repsText.contains("~") {
                assumptions.append("写的是 \(repsText) 次，按 \(reps) 算")
            }
        } else if let durationText = cell(durationIndex), let seconds = seconds(in: durationText) {
            value = seconds
            targetType = .durationSec
        }

        let rest = cell(restIndex).flatMap { seconds(in: $0) }
        let perSide = rawName.contains("每侧") || rawName.contains("单侧")

        let hit = ExerciseAliasResolver.match(for: rawName, memory: memory)

        return DraftItem(
            rawName: rawName,
            catalogId: hit?.catalogId,
            sets: sets,
            value: value,
            targetType: targetType,
            perSide: perSide,
            restSec: rest,
            assumptions: assumptions,
            origin: cells.joined(separator: " | "),
            reviewModifier: hit?.modifier,
            usedMemory: hit?.source == .memory
        )
    }

    private static func column(in header: [String], keys: [String]) -> Int? {
        header.firstIndex { cell in
            let lowered = cell.lowercased()
            return keys.contains { lowered.contains($0) }
        }
    }

    private static func number(in text: String) -> Int? {
        guard let match = DraftLineScanner.firstMatch(in: text, pattern: "[0-9]+") else { return nil }
        return Int(String(text[match.range]))
    }

    private static func seconds(in text: String) -> Int? {
        guard let value = number(in: text) else { return nil }
        let lowered = text.lowercased()
        if lowered.contains("分钟") || lowered.contains("min") || lowered.contains("分") {
            return value * 60
        }
        return value
    }
}
