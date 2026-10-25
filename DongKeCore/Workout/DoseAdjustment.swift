import Foundation

public enum DoseAdjustment {
    public static let repStep = 2
    public static let repCeiling = 15
    public static let repFloor = 5
    public static let freshReps = 8
    public static let setCeiling = 5
    public static let minimumSessions = 2
    public static let comfortableReserve = 2
    public static let loadStep = 1.025
    public static let deloadEvery = 3
    public static let deloadFactor = 0.6
    public static let painFactor = 0.8
    public static let painWindow: TimeInterval = 7 * 86_400
    public static let missedDaysForRebuild = 2
    public static let rebuildLookback = 14

    public static func propose(
        plan: WorkoutPlan,
        logs: [SetLog],
        sessionStarts: [Date] = [],
        now: Date = Date()
    ) -> PlanProposal? {
        propose(DoseContext(plan: plan, logs: logs, sessionStarts: sessionStarts, now: now))
    }

    public static func propose(_ context: DoseContext) -> PlanProposal? {
        guard context.asked || context.plan.source.isMachineWritten == false else { return nil }
        guard context.memory.isSilenced == false else { return nil }

        let sessions = loggedSessions(context.logs)
        if let safety = safetyProposal(context) { return safety }
        if let rebuild = rebuildProposal(context) { return rebuild }
        if let swap = swapProposal(context, sessions: sessions),
           context.memory.hasRejected(swap) == false { return swap }
        if let reduction = reductionProposal(context, sessions: sessions),
           context.memory.hasRejected(reduction) == false { return reduction }
        if let deload = deloadProposal(context) { return deload }
        if let dose = doseProposal(context, sessions: sessions),
           context.memory.hasRejected(dose) == false { return dose }
        return nil
    }

    public static func restoreProposal(
        from baseline: WorkoutPlan,
        current: WorkoutPlan,
        now: Date = Date()
    ) -> PlanProposal? {
        let originals = Dictionary(uniqueKeysWithValues: uniqueItems(of: baseline).map { ($0.itemId, $0) })
        var changes: [PlanProposal.Change] = []
        for item in uniqueItems(of: current) {
            guard let original = originals[item.itemId], original.target.type == .reps else { continue }
            let target = max(repFloor, Int((Double(original.target.value) * 0.8).rounded()))
            guard target > item.target.value else { continue }
            changes.append(PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .reps,
                fromValue: Double(item.target.value),
                toValue: Double(target)
            ))
        }
        guard changes.isEmpty == false else { return nil }
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: "上次那节做完了。这周回到停练前的八成，之后照常往上加。",
            createdAt: now
        )
    }

    public static func apply(_ proposal: PlanProposal, to plan: WorkoutPlan, now: Date = Date()) -> WorkoutPlan {
        var next = plan
        if proposal.droppedItemIds.isEmpty == false {
            next.days = next.days.map { day in
                var day = day
                day.blocks = day.blocks.compactMap { block in
                    var block = block
                    block.items = block.items.filter { proposal.droppedItemIds.contains($0.itemId) == false }
                    return block.items.isEmpty ? nil : block
                }
                return day
            }
        }
        for change in proposal.changes {
            for dayIndex in next.days.indices {
                for blockIndex in next.days[dayIndex].blocks.indices {
                    for itemIndex in next.days[dayIndex].blocks[blockIndex].items.indices
                    where next.days[dayIndex].blocks[blockIndex].items[itemIndex].itemId == change.itemId {
                        var item = next.days[dayIndex].blocks[blockIndex].items[itemIndex]
                        switch change.field {
                        case .reps:
                            item.target.value = Int(change.toValue.rounded())
                        case .sets:
                            item.sets = Int(change.toValue.rounded())
                        case .load:
                            item.load.value = change.toValue
                        case .exercise:
                            if let id = change.toId, let entry = ExerciseLibrary.entry(for: id) {
                                item.catalogId = entry.id
                                item.name = entry.name
                                item.load = Load(type: loadType(for: entry.equipment), value: 0)
                                if item.target.type == .reps {
                                    item.target.value = freshReps
                                }
                            }
                        }
                        next.days[dayIndex].blocks[blockIndex].items[itemIndex] = item
                    }
                }
            }
        }
        if proposal.kind != .rebuild {
            next.revision = plan.revision + 1
        }
        next.updatedAt = now
        return next
    }

    public static func loadType(for equipment: Equipment) -> LoadType {
        switch equipment {
        case .bodyweight, .bench: .bodyweight
        case .dumbbell: .dumbbell
        case .band: .band
        case .kettlebell: .kettlebell
        }
    }
}

struct LoggedSession {
    let startedAt: Date
    let logs: [SetLog]
}

extension DoseAdjustment {
    static func loggedSessions(_ logs: [SetLog]) -> [LoggedSession] {
        Dictionary(grouping: logs, by: \.sessionId)
            .map { _, group in
                LoggedSession(startedAt: group.map(\.completedAt).min() ?? .distantPast, logs: group)
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    static func uniqueItems(of plan: WorkoutPlan) -> [ExercisePrescription] {
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

    static func item(for prescriptionId: String, in plan: WorkoutPlan) -> ExercisePrescription? {
        uniqueItems(of: plan).first { $0.itemId == prescriptionId }
    }

    static func planDay(containing logs: [SetLog], in plan: WorkoutPlan) -> PlanDay? {
        let ids = Set(logs.map(\.prescriptionId))
        return plan.days.first { day in
            day.blocks.contains { block in
                block.items.contains { ids.contains($0.itemId) }
            }
        }
    }
}
