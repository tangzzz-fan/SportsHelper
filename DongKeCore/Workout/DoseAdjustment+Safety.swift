import Foundation

extension DoseAdjustment {
    static func safetyProposal(_ context: DoseContext) -> PlanProposal? {
        let cutoff = context.now.addingTimeInterval(-painWindow)
        let painful = context.logs
            .filter { $0.skipReason == .pain && $0.completedAt >= cutoff }
            .sorted { $0.completedAt > $1.completedAt }
        guard painful.isEmpty == false else { return nil }

        var changes: [PlanProposal.Change] = []
        for log in painful {
            guard let item = item(for: log.prescriptionId, in: context.plan) else { continue }
            guard changes.contains(where: { $0.itemId == item.itemId }) == false else { continue }
            guard let change = soften(item) else { continue }
            changes.append(change)
        }
        guard changes.isEmpty == false else { return nil }

        let names = changes.map(\.name).joined(separator: "、")
        return PlanProposal(
            kind: .safety,
            changes: changes,
            reason: "上周 \(names) 做到疼。这周先轻一点，不加量。",
            createdAt: context.now
        )
    }

    static func soften(_ item: ExercisePrescription) -> PlanProposal.Change? {
        if item.load.type != .bodyweight, item.load.value > 0 {
            let target = (item.load.value * painFactor * 10).rounded() / 10
            guard target < item.load.value else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .load,
                fromValue: item.load.value,
                toValue: target
            )
        }
        if item.target.type == .reps {
            let target = max(repFloor, Int((Double(item.target.value) * painFactor).rounded()))
            guard target < item.target.value else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .reps,
                fromValue: Double(item.target.value),
                toValue: Double(target)
            )
        }
        guard item.sets > 1 else { return nil }
        return PlanProposal.Change(
            itemId: item.itemId,
            name: item.name,
            field: .sets,
            fromValue: Double(item.sets),
            toValue: Double(item.sets - 1)
        )
    }
}

extension DoseAdjustment {
    static func rebuildProposal(_ context: DoseContext) -> PlanProposal? {
        guard missedPlanDays(context) >= missedDaysForRebuild else { return nil }
        let items = uniqueItems(of: context.plan)
        guard items.count >= 3 else { return nil }

        var kept: [ExercisePrescription] = []
        var dropped: [String] = []
        for (index, item) in items.enumerated() {
            if index % 2 == 1 {
                dropped.append(item.itemId)
            } else {
                kept.append(item)
            }
        }
        let changes = kept.compactMap { item -> PlanProposal.Change? in
            let target = max(1, item.sets / 2)
            guard target < item.sets else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .sets,
                fromValue: Double(item.sets),
                toValue: Double(target)
            )
        }
        guard changes.isEmpty == false || dropped.isEmpty == false else { return nil }

        return PlanProposal(
            kind: .rebuild,
            changes: changes,
            droppedItemIds: dropped,
            reason: "有一阵没练了。这节课只做一半的动作、一半的组，做完就算完成。",
            createdAt: context.now
        )
    }

    static func missedPlanDays(_ context: DoseContext) -> Int {
        let trainingDays = Set(context.plan.days.filter { $0.isRestDay == false }.map(\.weekday))
        guard trainingDays.isEmpty == false else { return 0 }

        let starts = context.sessionStarts + context.logs.map(\.completedAt)
        let lastSession = starts.max()
        var missed = 0
        var day = context.calendar.date(byAdding: .day, value: -1, to: context.now) ?? context.now
        for _ in 0..<rebuildLookback {
            if let lastSession, day <= lastSession { break }
            let component = context.calendar.component(.weekday, from: day)
            if let weekday = Weekday.allCases.first(where: { $0.systemWeekday == component }),
               trainingDays.contains(weekday) {
                missed += 1
            }
            guard let previous = context.calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return missed
    }
}
