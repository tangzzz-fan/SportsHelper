import Foundation

extension DoseAdjustment {
    /// 连续两次，用户把每一组都加到自己更重的重量上——不是他做不动，是处方写轻了。
    /// 这种情况把处方改成他实际用的重量，次数不动；也不该被记成「没完成」或「太累」。
    static func selfLoadedProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        let recent = Array(sessions.suffix(minimumSessions))
        guard recent.count == minimumSessions else { return nil }

        var changes: [PlanProposal.Change] = []
        for item in uniqueItems(of: context.plan) {
            guard item.load.type != .bodyweight, item.load.value > 0 else { continue }
            guard let used = selfLoadedWeight(of: item, in: recent) else { continue }
            let target = context.rack.snapped(used)
            guard target > item.load.value else { continue }
            changes.append(PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .load,
                fromValue: item.load.value,
                toValue: target
            ))
        }
        guard changes.isEmpty == false else { return nil }

        let names = changes.map(\.name).joined(separator: "、")
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: "最近两次 \(names) 你都用了比处方更重的重量，而且每组都做完了。按你实际用的改，次数不动。",
            createdAt: context.now
        )
    }

    /// 两次课都用同一个、比处方更重的重量做满全部组，返回那个重量。
    static func selfLoadedWeight(of item: ExercisePrescription, in sessions: [LoggedSession]) -> Double? {
        var weights: [Double] = []
        for session in sessions {
            let mine = session.logs.filter {
                $0.prescriptionId == item.itemId && $0.origin == .prescribed && $0.status != .skipped
            }
            guard mine.count >= item.sets else { return nil }
            let loads = mine.compactMap(\.actualLoad?.value)
            guard loads.count == mine.count, let first = loads.first else { return nil }
            guard loads.allSatisfy({ abs($0 - first) < 0.001 }) else { return nil }
            guard first > item.load.value + 0.001 else { return nil }
            weights.append(first)
        }
        return weights.count == sessions.count ? weights.last : nil
    }
}
