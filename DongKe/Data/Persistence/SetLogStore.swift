import Foundation
import SwiftData
import DongKeCore

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
            catalogId: log.catalogId,
            setIndex: log.setIndex,
            statusRaw: log.status.rawValue,
            plannedValue: log.plannedValue,
            actualValue: log.actualValue,
            skipReasonRaw: log.skipReason?.rawValue,
            completedAt: log.completedAt,
            rpe: log.rpe,
            originRaw: log.origin.rawValue
        )
        context.insert(entity)
        try? context.save()
    }

    func logs(for sessionId: UUID) -> [SetLog] {
        let descriptor = FetchDescriptor<SetLogEntity>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.completedAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).compactMap(Self.log(from:))
    }

    func recentLogs(limit: Int = 600) -> [SetLog] {
        var descriptor = FetchDescriptor<SetLogEntity>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).compactMap(Self.log(from:))
    }

    private static func log(from entity: SetLogEntity) -> SetLog? {
        guard let status = SetStatus(rawValue: entity.statusRaw) else { return nil }
        return SetLog(
            id: entity.id,
            sessionId: entity.sessionId,
            prescriptionId: entity.prescriptionId,
            catalogId: entity.catalogId,
            setIndex: entity.setIndex,
            status: status,
            plannedValue: entity.plannedValue,
            actualValue: entity.actualValue,
            skipReason: entity.skipReasonRaw.flatMap(SkipReason.init(rawValue:)),
            rpe: entity.rpe,
            completedAt: entity.completedAt,
            origin: entity.originRaw.flatMap(SetOrigin.init(rawValue:)) ?? .prescribed
        )
    }

    func deleteAll() {
        try? context.delete(model: SetLogEntity.self)
        try? context.save()
    }
}
