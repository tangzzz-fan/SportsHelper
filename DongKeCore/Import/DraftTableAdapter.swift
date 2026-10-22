import Foundation

public enum DraftTableAdapter {
    public static func draft(from text: String) -> PlanDraft? {
        var title: String?
        var days: [DraftDay] = []
        var header: [String]?
        var openDayIndex: Int?
        var pendingWeekday: Weekday?
        var pendingLabel: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("|") {
                let cells = splitRow(line)
                guard !cells.isEmpty else { continue }
                if isDivider(cells) { continue }

                if header == nil {
                    header = cells
                    continue
                }
                guard let header, let item = makeItem(cells: cells, header: header) else { continue }

                if openDayIndex == nil {
                    days.append(DraftDay(
                        order: days.count + 1,
                        label: pendingLabel ?? "训练",
                        weekday: pendingWeekday
                    ))
                    openDayIndex = days.count - 1
                }
                days[openDayIndex!].items.append(item)
                continue
            }

            header = nil
            openDayIndex = nil

            if let weekday = DraftLineScanner.weekday(in: line) {
                pendingWeekday = weekday
                let remainder = DraftLineScanner.removingWeekdayToken(in: line)
                let label = DraftLineScanner.cleanedName(remainder)
                pendingLabel = label.isEmpty ? weekday.chineseName : label
                continue
            }

            if let label = dayLabel(from: line) {
                pendingWeekday = nil
                pendingLabel = label
                continue
            }

            if title == nil, DraftLineScanner.looksLikeTitle(line) {
                title = DraftLineScanner.cleanedName(line)
            }
        }

        guard days.contains(where: { !$0.items.isEmpty }) else { return nil }
        return PlanDraft(title: title, days: days, cautions: [], source: .markdownTable)
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

    private static func dayLabel(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let label = DraftLineScanner.cleanedName(trimmed)
        return label.isEmpty ? nil : label
    }

    private static func makeItem(cells: [String], header: [String]) -> DraftItem? {
        let nameIndex = column(in: header, keys: ["动作", "exercise", "movement", "名称", "训练"])
        let setsIndex = column(in: header, keys: ["组数", "set", "series", "组"])
        let repsIndex = column(in: header, keys: ["次数", "rep", "repetition", "times", "次"])
        let durationIndex = column(in: header, keys: ["秒", "时长", "duration", "hold", "sec", "time"])
        let restIndex = column(in: header, keys: ["休息", "rest", "interval", "间隔"])
        let notesIndex = column(in: header, keys: ["备注", "note", "说明", "comment"])

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

        return DraftItem(
            rawName: rawName,
            catalogId: ExerciseAliasResolver.catalogId(for: rawName),
            sets: sets,
            value: value,
            targetType: targetType,
            perSide: perSide,
            restSec: rest,
            assumptions: assumptions,
            origin: cells.joined(separator: " | ")
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
