import Foundation

/// 训练中换动作的候选。三个约束，按优先级：
/// 1. 先给低阶版本（用户做不动时才换，方向只会往轻里走）；
/// 2. 再给同主肌群、器械可用、同类型的动作；
/// 3. 最多 3 个——超过 3 个就不叫「紧急替换」，叫「重新选动作」。
public enum SwapCandidates {
    public static let limit = 3

    public static func suggestions(
        for current: ExercisePrescription,
        available: [Equipment]
    ) -> [ExerciseEntry] {
        guard let entry = ExerciseLibrary.entry(for: current.catalogId) else { return [] }

        var result: [ExerciseEntry] = []
        var seen: Set<String> = [entry.id]

        if let id = entry.regressionId,
           let regression = ExerciseLibrary.entry(for: id),
           regression.isStatic == entry.isStatic,
           seen.insert(id).inserted {
            result.append(regression)
        }

        let pool = ExerciseLibrary.all.filter { candidate in
            guard seen.contains(candidate.id) == false else { return false }
            guard candidate.group == entry.group, candidate.isStatic == entry.isStatic else { return false }
            return isAvailable(candidate.equipment, in: available)
        }

        let ordered = pool.sorted { lhs, rhs in
            let left = lhs.affectedParts.intersection(entry.affectedParts).count
            let right = rhs.affectedParts.intersection(entry.affectedParts).count
            if left != right { return left > right }
            return lhs.id < rhs.id
        }

        for candidate in ordered where result.count < limit {
            result.append(candidate)
        }
        return Array(result.prefix(limit))
    }

    /// 自重永远可用——器械列表没填全时，至少还能退到徒手。
    static func isAvailable(_ equipment: Equipment, in available: [Equipment]) -> Bool {
        equipment == .bodyweight || available.contains(equipment)
    }

    /// 换过去之后的处方：保留 `itemId`（组数、流程、断点都靠它串），
    /// 换掉动作与名字；目标值不动（同类型动作的可比性最高）；负重动作转自重时清零。
    public static func prescription(
        replacing current: ExercisePrescription,
        with entry: ExerciseEntry
    ) -> ExercisePrescription {
        var next = current
        next.catalogId = entry.id
        next.name = entry.name
        if entry.equipment == .bodyweight {
            next.load = Load(type: .bodyweight, value: 0)
        }
        next.notes = ""
        return next
    }
}
