import Foundation

public enum DoseAdjustment {
    public static let repStep = 2
    public static let repCeiling = 15
    public static let minimumSessions = 2

    public static func propose(
        plan: WorkoutPlan,
        logs: [SetLog],
        sessionStarts: [Date] = [],
        now: Date = Date()
    ) -> PlanProposal? {
        let bySession = Dictionary(grouping: logs, by: \.sessionId)
        let sessions = bySession
            .map { (id: $0.key, startedAt: $0.value.map(\.completedAt).min() ?? now, logs: $0.value) }
            .sorted { $0.startedAt < $1.startedAt }

        var changes: [PlanProposal.Change] = []
        for item in uniqueItems(of: plan) where item.target.type == .reps {
            let history = sessions.filter { session in
                session.logs.contains { $0.prescriptionId == item.itemId }
            }
            guard history.count >= minimumSessions else { continue }
            let recent = history.suffix(minimumSessions)
            guard recent.allSatisfy({ clearedEverySet(of: item, in: $0.logs) }) else { continue }
            let target = item.target.value + repStep
            guard target <= repCeiling else { continue }
            changes.append(
                PlanProposal.Change(
                    itemId: item.itemId,
                    name: item.name,
                    field: .reps,
                    fromValue: item.target.value,
                    toValue: target
                )
            )
        }

        guard changes.isEmpty == false else { return nil }
        let names = changes.map(\.name).joined(separator: "、")
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: "最近两次训练，\(names) 每组都多做了至少 1 个",
            createdAt: now
        )
    }

    public static func apply(
        _ proposal: PlanProposal,
        to plan: WorkoutPlan,
        now: Date = Date()
    ) -> WorkoutPlan {
        var next = plan
        for change in proposal.changes {
            for dayIndex in next.days.indices {
                for blockIndex in next.days[dayIndex].blocks.indices {
                    for itemIndex in next.days[dayIndex].blocks[blockIndex].items.indices
                    where next.days[dayIndex].blocks[blockIndex].items[itemIndex].itemId == change.itemId {
                        var item = next.days[dayIndex].blocks[blockIndex].items[itemIndex]
                        switch change.field {
                        case .reps:
                            item.target.value = change.toValue
                        case .sets:
                            item.sets = change.toValue
                        case .load:
                            item.load.value = Double(change.toValue)
                        case .exercise:
                            continue
                        }
                        next.days[dayIndex].blocks[blockIndex].items[itemIndex] = item
                    }
                }
            }
        }
        next.revision = plan.revision + 1
        next.updatedAt = now
        return next
    }

    private static func uniqueItems(of plan: WorkoutPlan) -> [ExercisePrescription] {
        var seen = Set<String>()
        var items: [ExercisePrescription] = []
        for day in plan.days {
            for block in day.blocks {
                for item in block.items where seen.insert(item.itemId).inserted {
                    items.append(item)
                }
            }
        }
        return items
    }

    private static func clearedEverySet(of item: ExercisePrescription, in logs: [SetLog]) -> Bool {
        let mine = logs.filter { $0.prescriptionId == item.itemId }
        guard mine.count >= item.sets else { return false }
        return mine.allSatisfy { log in
            log.status == .done
                && log.plannedValue == item.target.value
                && log.actualValue >= log.plannedValue + 1
        }
    }
}
