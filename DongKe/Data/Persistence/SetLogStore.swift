import Foundation
import SwiftData
import DongKeCore

struct SetLogTally: Equatable, Sendable {
    var done = 0
    var downgraded = 0
    var skipped = 0

    var logged: Int { done + downgraded + skipped }
}

@MainActor
@Observable
final class SetLogStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ log: SetLog) {
        let entity = SetLogEntity(
            id: log.id,
            sessionId: log.sessionId,
            prescriptionId: log.prescriptionId,
            setIndex: log.setIndex,
            statusRaw: log.status.rawValue,
            plannedValue: log.plannedValue,
            actualValue: log.actualValue,
            skipReasonRaw: log.skipReason?.rawValue,
            completedAt: log.completedAt
        )
        context.insert(entity)
        try? context.save()
    }

    func logs(for sessionId: UUID) -> [SetLog] {
        let descriptor = FetchDescriptor<SetLogEntity>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.completedAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).compactMap { entity in
            guard let status = SetStatus(rawValue: entity.statusRaw) else { return nil }
            return SetLog(
                id: entity.id,
                sessionId: entity.sessionId,
                prescriptionId: entity.prescriptionId,
                setIndex: entity.setIndex,
                status: status,
                plannedValue: entity.plannedValue,
                actualValue: entity.actualValue,
                skipReason: entity.skipReasonRaw.flatMap(SkipReason.init(rawValue:)),
                completedAt: entity.completedAt
            )
        }
    }

    func tally(for sessionId: UUID) -> SetLogTally {
        logs(for: sessionId).reduce(into: SetLogTally()) { tally, log in
            switch log.status {
            case .done: tally.done += 1
            case .downgraded: tally.downgraded += 1
            case .skipped: tally.skipped += 1
            }
        }
    }

    func deleteAll() {
        try? context.delete(model: SetLogEntity.self)
        try? context.save()
    }
}
