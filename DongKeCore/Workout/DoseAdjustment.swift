import Foundation

public enum DoseAdjustment {
    public static let repStep = 2
    public static let repCeiling = 15
    public static let repFloor = 5
    public static let freshReps = 8
    public static let setCeiling = 5
    public static let minimumSessions = 2
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

private struct LoggedSession {
    let startedAt: Date
    let logs: [SetLog]
}

private extension DoseAdjustment {
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

private extension DoseAdjustment {
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

private extension DoseAdjustment {
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

private extension DoseAdjustment {
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

private extension DoseAdjustment {
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
        guard item.target.type == .reps else { return nil }
        let target = max(repFloor, item.target.value - repStep)
        guard target < item.target.value else { return nil }
        return PlanProposal.Change(
            itemId: item.itemId,
            name: item.name,
            field: .reps,
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

private extension DoseAdjustment {
    static func deloadProposal(_ context: DoseContext) -> PlanProposal? {
        guard context.memory.doseStreak >= deloadEvery else { return nil }
        let changes = uniqueItems(of: context.plan).compactMap { item -> PlanProposal.Change? in
            guard item.target.type == .reps else { return nil }
            let target = max(repFloor, Int((Double(item.target.value) * deloadFactor).rounded()))
            guard target < item.target.value else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .reps,
                fromValue: Double(item.target.value),
                toValue: Double(target)
            )
        }
        guard changes.isEmpty == false else { return nil }
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: "连着加了三次。这周缓一缓，次数降到六成，下周接着加。",
            createdAt: context.now,
            isDeload: true
        )
    }
}

private extension DoseAdjustment {
    enum Lever: Int, Comparable {
        case reps = 0
        case load = 1
        case sets = 2

        static func < (lhs: Lever, rhs: Lever) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static func doseProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        var pending: [(item: ExercisePrescription, lever: Lever)] = []
        for item in uniqueItems(of: context.plan) {
            guard let lever = lever(for: item) else { continue }
            let history = sessions.filter { session in
                session.logs.contains { $0.prescriptionId == item.itemId }
            }
            guard history.count >= minimumSessions else { continue }
            guard history.suffix(minimumSessions).allSatisfy({ clearedEverySet(of: item, in: $0.logs) }) else { continue }
            pending.append((item, lever))
        }
        guard let level = pending.map(\.lever).min() else { return nil }
        let chosen = pending.filter { $0.lever == level }.map(\.item)
        let changes = chosen.compactMap { change(for: $0, lever: level, amplitude: context.memory.loadAmplitude) }
        guard changes.isEmpty == false else { return nil }

        let names = changes.map(\.name).joined(separator: "、")
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: reason(for: level, names: names, items: chosen),
            createdAt: context.now
        )
    }

    static func lever(for item: ExercisePrescription) -> Lever? {
        guard item.target.type == .reps else { return nil }
        if item.target.value + repStep <= repCeiling { return .reps }
        if item.load.type != .bodyweight, item.load.value > 0 { return .load }
        if item.sets < setCeiling { return .sets }
        return nil
    }

    static func change(for item: ExercisePrescription, lever: Lever, amplitude: Double) -> PlanProposal.Change? {
        switch lever {
        case .reps:
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .reps,
                fromValue: Double(item.target.value),
                toValue: Double(item.target.value + repStep)
            )
        case .load:
            let target = (item.load.value * amplitude * 10).rounded() / 10
            guard target > item.load.value else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .load,
                fromValue: item.load.value,
                toValue: target
            )
        case .sets:
            guard item.sets < setCeiling else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: .sets,
                fromValue: Double(item.sets),
                toValue: Double(item.sets + 1)
            )
        }
    }

    static func reason(for lever: Lever, names: String, items: [ExercisePrescription]) -> String {
        switch lever {
        case .reps:
            return "最近两次训练，\(names) 每组都多做了至少 1 个"
        case .load:
            let reps = items.first?.target.value ?? repCeiling
            return "\(names) 次数到顶（\(reps) 次），两次都多做了。加重一档，次数回到下限"
        case .sets:
            return "\(names) 次数到顶，也没有可加的重量。这周加一组"
        }
    }

    static func clearedEverySet(of item: ExercisePrescription, in logs: [SetLog]) -> Bool {
        let mine = logs.filter { $0.prescriptionId == item.itemId }
        guard mine.count >= item.sets else { return false }
        return mine.allSatisfy { log in
            log.status == .done
                && log.plannedValue == item.target.value
                && log.actualValue >= log.plannedValue + 1
        }
    }
}
