import Foundation

public enum AIPromptBuilder {
    public static func makeMessages(profile: UserProfile, extraNote: String = "") -> [ChatMessage] {
        [
            ChatMessage(role: .system, content: systemPrompt()),
            ChatMessage(role: .user, content: userBrief(profile: profile, extraNote: extraNote))
        ]
    }

    public static func copyablePrompt(profile: UserProfile, extraNote: String = "") -> String {
        makeMessages(profile: profile, extraNote: extraNote)
            .map(\.content)
            .joined(separator: "\n\n")
    }

    public static func systemPrompt() -> String {
        """
        你是健身计划生成器。只输出一个 JSON 对象，不要输出解释，不要用 markdown 代码块包裹。
        必须严格遵守下面这份 JSON Schema，字段名、类型、枚举值一字不差：

        \(PlanSchemaJSON.text)

        硬性要求：
        1 所有字段必须出现；没有内容时字符串填空串，数组填 []，数值填 0；禁止出现 null。
        2 days 固定 7 项，dayIndex 1 到 7 对应周一到周日；休息日也要有完整对象，isRestDay 为 true、blocks 为 []。
        3 meta.daysPerWeek 必须等于 isRestDay 为 false 的天数。
        4 catalogId 只能取以下值之一：\(catalogIds)；库外动作用 custom_ 前缀。
        5 单组目标三选一：type 为 reps 时 value 是次数，duration_sec 时是秒数，distance_m 时是米数。
        6 notes 写动作要点，不超过 60 字，不要写营销文案。
        7 居家场景，默认无器械；需要器械时必须使用用户已声明的器械。
        """
    }

    public static func userBrief(profile: UserProfile, extraNote: String) -> String {
        var lines: [String] = []
        let weight = weightText(profile.weightKg)
        lines.append("身高 \(profile.heightCm) cm，体重 \(weight) kg，年龄 \(profile.age) 岁，性别 \(profile.sex.chineseName)。")
        lines.append("目标：\(profile.goal.chineseName)；水平：\(profile.level.chineseName)。")
        lines.append("每周可训练：\(weekdayText(profile.availableWeekdays))；每次约 \(profile.sessionMinutes) 分钟。")
        lines.append("可用器械：\(equipmentText(profile.equipment))。")
        let injuries = profile.injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        if injuries.isEmpty == false {
            lines.append("伤病限制：\(injuries)。")
        }
        let note = extraNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.isEmpty == false {
            lines.append("补充要求：\(note)。")
        }
        lines.append("请按以上条件生成一周计划。")
        return lines.joined(separator: "\n")
    }

    private static var catalogIds: String {
        ExerciseLibrary.all.map(\.id).joined(separator: ", ")
    }

    private static func weekdayText(_ weekdays: [Weekday]) -> String {
        weekdays.isEmpty ? "未指定" : weekdays.map(\.chineseName).joined(separator: "、")
    }

    private static func equipmentText(_ equipment: [Equipment]) -> String {
        equipment.isEmpty ? "徒手" : equipment.map(\.chineseName).joined(separator: "、")
    }

    private static func weightText(_ weight: Double) -> String {
        weight == weight.rounded() ? String(Int(weight)) : String(format: "%.1f", weight)
    }
}
