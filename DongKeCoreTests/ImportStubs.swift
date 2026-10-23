import Foundation
@testable import DongKeCore

enum ImportStub {
    static func text(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    static func day(_ weekday: String, _ exercises: [String]) -> String {
        text([weekday] + exercises)
    }

    static func week(_ index: Int, _ days: [String]) -> String {
        text(["第 \(index) 周"] + days)
    }

    static func repeated(_ line: String, times: Int) -> String {
        text(Array(repeating: line, count: times))
    }

    static let catalogExercises = [
        "深蹲 3×12", "臀桥 3×15", "平板支撑 3组", "开合跳 3×30秒", "高抬腿 3×30秒",
        "登山跑 3×30秒", "卷腹 3×15", "死虫 3×10", "鸟狗 3×10", "超人 3×10",
        "提踵 3×15", "弓步蹲 3×10", "俯卧撑 3×10", "靠墙静蹲 3组", "俄罗斯转体 3×20",
        "侧平板支撑 3组", "哑铃划船 3×12", "哑铃推举 3×12"
    ]

    static let customExercises = [
        "壶铃摆动 3×12", "农夫行走 3组 40米", "弹力带划船 3×12"
    ]

    static func exercises(count: Int) -> [String] {
        let pool = catalogExercises + customExercises
        guard count > pool.count else { return Array(pool.prefix(count)) }
        return pool + (1...(count - pool.count)).map { "自编动作\($0) 3×12" }
    }

    static func genericJSON(days: [(day: String, items: [String])]) -> String {
        let payload: [String: Any] = [
            "days": days.map { entry in
                [
                    "day": entry.day,
                    "items": entry.items.map { name in ["name": name, "sets": 3, "reps": 12] }
                ]
            }
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return String(decoding: data, as: UTF8.self)
    }

    static func rawJSON(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(decoding: data, as: UTF8.self)
    }
}
