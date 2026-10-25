import Foundation

extension DoseAdjustment {
    static func swapProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        guard let latest = sessions.last else { return nil }
        let wanted = latest.logs.filter { $0.skipReason == .noEquipment }
        guard wanted.isEmpty == false else { return nil }

        for log in wanted {
            guard let item = item(for: log.prescriptionId, in: context.plan) else { continue }
            guard let entry = ExerciseLibrary.entry(for: item.catalogId),
                  let alternativeId = entry.alternativeId,
                  let alternative = ExerciseLibrary.entry(for: alternativeId) else { continue }
            let change = PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .exercise,
                fromValue: 0,
                toValue: 0,
                toName: alternative.name,
                toId: alternative.id
            )
            return PlanProposal(
                kind: .swap,
                changes: [change],
                reason: "上次 \(item.name) 是没器械才跳过的。换一个不用器械的。",
                createdAt: context.now
            )
        }
        return nil
    }
}

extension DoseAdjustment {
    static func reductionProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        if let tooHard = tooHardProposal(context, sessions: sessions) { return tooHard }
        return noTimeProposal(context, sessions: sessions)
    }

    static func tooHardProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        let recent = Array(sessions.suffix(minimumSessions))
        guard recent.count == minimumSessions else { return nil }

        var changes: [PlanProposal.Change] = []
        for item in uniqueItems(of: context.plan) {
            let hits = recent.filter { session in
                session.logs.contains { $0.prescriptionId == item.itemId && $0.skipReason == .tooHard }
            }
            guard hits.count == minimumSessions else { continue }
            guard let change = lighten(item) else { continue }
            changes.append(change)
        }
        guard changes.isEmpty == false else { return nil }
        let names = changes.map(\.name).joined(separator: "、")
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: "最近两次 \(names) 都是「太累」跳过的。这周降一点强度，组数不动。",
            createdAt: context.now
        )
    }

    static func lighten(_ item: ExercisePrescription) -> PlanProposal.Change? {
        if item.load.type != .bodyweight, item.load.value > 0 {
            let target = (item.load.value * 0.9 * 10).rounded() / 10
            guard target < item.load.value else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .load,
                fromValue: item.load.value,
                toValue: target
            )
        }
        guard let axis = ProgressionAxis(item.target),
              let target = axis.eased(item.target.value) else { return nil }
        return PlanProposal.Change(
            itemId: item.itemId,
            name: item.name,
            field: axis.field,
            fromValue: Double(item.target.value),
            toValue: Double(target)
        )
    }

    static func noTimeProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        let recent = Array(sessions.suffix(3))
        guard recent.count == 3, let latest = recent.last else { return nil }
        guard let day = planDay(containing: latest.logs, in: context.plan) else { return nil }

        let items = day.blocks.flatMap(\.items)
        guard items.count > 5 else { return nil }

        let repeated = items.filter { item in
            recent.allSatisfy { session in
                session.logs.contains { $0.prescriptionId == item.itemId && $0.skipReason == .noTime }
            }
        }
        guard let victim = repeated.last else { return nil }

        return PlanProposal(
            kind: .dose,
            changes: [],
            droppedItemIds: [victim.itemId],
            reason: "连着三次没时间。去掉 \(victim.name)，剩下的就能做完。",
            createdAt: context.now
        )
    }
}
