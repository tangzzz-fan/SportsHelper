import Foundation

extension DoseAdjustment {
    static func deloadProposal(_ context: DoseContext) -> PlanProposal? {
        guard context.memory.doseStreak >= deloadEvery else { return nil }
        let changes = uniqueItems(of: context.plan).compactMap { item -> PlanProposal.Change? in
            guard let axis = ProgressionAxis(item.target),
                  let target = axis.softened(item.target.value, factor: deloadFactor) else { return nil }
            return PlanProposal.Change(
                itemId: item.itemId,
                name: item.name,
                field: axis.field,
                fromValue: Double(item.target.value),
                toValue: Double(target)
            )
        }
        guard changes.isEmpty == false else { return nil }
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: "连着加了三次。这周缓一缓，次数或保持时间降到六成，下周接着加。",
            createdAt: context.now,
            isDeload: true
        )
    }
}

extension DoseAdjustment {
    enum Lever: Int, Comparable {
        case reps = 0
        case load = 1
        case sets = 2

        static func < (lhs: Lever, rhs: Lever) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static func doseProposal(_ context: DoseContext, sessions: [LoggedSession]) -> PlanProposal? {
        var cleared: [(item: ExercisePrescription, lever: Lever)] = []
        var reserved: [ExercisePrescription] = []

        for item in uniqueItems(of: context.plan) {
            let history = sessions.filter { session in
                session.logs.contains { $0.prescriptionId == item.itemId }
            }
            guard history.count >= minimumSessions else { continue }
            let recent = history.suffix(minimumSessions)

            if recent.allSatisfy({ clearedEverySet(of: item, in: $0.logs) }) {
                guard let lever = lever(for: item) else { continue }
                cleared.append((item, lever))
                continue
            }
            guard let axis = ProgressionAxis(item.target), axis.raised(item.target.value) != nil else { continue }
            guard recent.allSatisfy({ leftReserve(of: item, in: $0.logs) }) else { continue }
            reserved.append(item)
        }

        if let strong = clearedProposal(context, cleared: cleared) { return strong }
        return reserveProposal(context, reserved: reserved)
    }

    static func clearedProposal(
        _ context: DoseContext,
        cleared: [(item: ExercisePrescription, lever: Lever)]
    ) -> PlanProposal? {
        guard let level = cleared.map(\.lever).min() else { return nil }
        let chosen = cleared.filter { $0.lever == level }.map(\.item)
        let changes = chosen.compactMap { change(for: $0, lever: level, amplitude: context.memory.loadAmplitude) }
        guard changes.isEmpty == false else { return nil }
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: reason(for: level, names: changes.map(\.name).joined(separator: "、"), items: chosen),
            createdAt: context.now
        )
    }

    static func reserveProposal(_ context: DoseContext, reserved: [ExercisePrescription]) -> PlanProposal? {
        let dynamic = reserved.filter { ProgressionAxis($0.target) == .reps }
        let holds = reserved.filter { ProgressionAxis($0.target) == .holdSeconds }
        let axis: ProgressionAxis
        let chosen: [ExercisePrescription]
        if dynamic.isEmpty == false {
            axis = .reps
            chosen = dynamic
        } else if holds.isEmpty == false {
            axis = .holdSeconds
            chosen = holds
        } else {
            return nil
        }
        let changes = chosen.compactMap { item in
            axis == .reps
                ? change(for: item, lever: .reps, amplitude: context.memory.loadAmplitude)
                : holdChange(for: item)
        }
        guard changes.isEmpty == false else { return nil }
        return PlanProposal(
            kind: .dose,
            changes: changes,
            reason: reserveReason(names: changes.map(\.name).joined(separator: "、"), axis: axis),
            createdAt: context.now
        )
    }

    static func reserveReason(names: String, axis: ProgressionAxis) -> String {
        switch axis {
        case .reps:
            return "最近两次，\(names) 的最后一组你都觉得还能做三次以上。次数加两个，负重先不动。"
        case .holdSeconds:
            return "最近两次，\(names) 的最后一组你都觉得还能撑。保持时间加 \(ProgressionAxis.holdStep) 秒，最长到 \(ProgressionAxis.holdCeiling) 秒。"
        }
    }

    static func leftReserve(of item: ExercisePrescription, in logs: [SetLog]) -> Bool {
        guard ProgressionAxis(item.target) != nil else { return false }
        let mine = logs.filter { $0.prescriptionId == item.itemId && $0.origin == .prescribed }
        guard let last = mine.max(by: { $0.setIndex < $1.setIndex }) else { return false }
        guard last.status == .done, last.plannedValue == item.target.value else { return false }
        guard let rpe = last.rpe else { return false }
        return rpe <= comfortableReserve
    }

    static func lever(for item: ExercisePrescription) -> Lever? {
        guard item.target.type == .reps else { return nil }
        if item.target.value + repStep <= repCeiling { return .reps }
        if item.load.type != .bodyweight, item.load.value > 0 { return .load }
        if item.sets < setCeiling { return .sets }
        return nil
    }

    static func holdChange(for item: ExercisePrescription) -> PlanProposal.Change? {
        guard let axis = ProgressionAxis(item.target),
              let next = axis.raised(item.target.value) else { return nil }
        return PlanProposal.Change(
            itemId: item.itemId,
            name: item.name,
            field: .hold,
            fromValue: Double(item.target.value),
            toValue: Double(next)
        )
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
        let mine = logs.filter { $0.prescriptionId == item.itemId && $0.origin == .prescribed }
        guard mine.count >= item.sets else { return false }
        return mine.allSatisfy { log in
            log.status == .done
                && log.plannedValue == item.target.value
                && log.actualValue >= log.plannedValue + 1
        }
    }
}
