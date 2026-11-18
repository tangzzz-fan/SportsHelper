import Foundation

public extension Load {
    /// 纪录与预测的分组键：「dumbbell:8」「bodyweight:0」。
    /// 8kg 的 12 个和 10kg 的 9 个不是同一件事，不能互相覆盖。
    var recordKey: String { "\(type.rawValue):\(WeightText.format(value))" }

    /// 「10kg」「弹力带」。自重且 0kg 时返回 nil——不显示，也不占位。
    var shortText: String? {
        switch type {
        case .band:
            return "弹力带"
        case .bodyweight:
            return value > 0 ? WeightText.format(value) + "kg" : nil
        case .dumbbell, .barbell, .kettlebell, .machine, .other:
            return value > 0 ? WeightText.format(value) + "kg" : nil
        }
    }
}

public enum WeightText {
    /// 8.0 → 「8」，8.5 → 「8.5」。训练页一行里不出现没有意义的小数位。
    public static func format(_ value: Double) -> String {
        value == value.rounded()
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}

public extension ExercisePrescription {
    /// 训练页那一行：「10kg · 12 次 × 4 组」。
    /// `load` 来自当前会话（用户可能改过），不是处方里的值；传 nil 就是处方没重量。
    func workoutDoseLine(load: Load?) -> String {
        let weight = load?.shortText ?? ""
        let prefix = weight.isEmpty ? "" : "\(weight) · "
        let perSide = target.perSide ? " / 侧" : ""
        return "\(prefix)\(target.doseText)\(perSide) × \(sets) 组"
    }
}
