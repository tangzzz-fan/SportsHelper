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

    /// 返回是否落库成功。失败时调用方必须保留待发条目，不能当已同步清掉。
    @discardableResult
    func add(_ log: SetLog) -> Bool {
        let entity = SetLogEntity(
            id: log.id,
            sessionId: log.sessionId,
            prescriptionId: log.prescriptionId,
            catalogId: log.catalogId,
            targetTypeRaw: log.targetType?.rawValue,
            setIndex: log.setIndex,
            statusRaw: log.status.rawValue,
            plannedValue: log.plannedValue,
            actualValue: log.actualValue,
            actualLoadValue: log.actualLoad?.value,
            actualLoadTypeRaw: log.actualLoad?.type.rawValue,
            swappedFromCatalogId: log.swappedFromCatalogId,
            predictedValue: log.predictedValue,
            skipReasonRaw: log.skipReason?.rawValue,
            completedAt: log.completedAt,
            rpe: log.rpe,
            originRaw: log.origin.rawValue
        )
        context.insert(entity)
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    /// 跨设备同步用：同一账本键已存在就不插第二行。
    @discardableResult
    func addIfAbsent(_ log: SetLog) -> Bool {
        let key = SetLogKey(log)
        if logs(for: log.sessionId).contains(where: { SetLogKey($0) == key }) {
            return true
        }
        return add(log)
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

    func logs(forCatalogIds ids: [String], before date: Date = .distantFuture) -> [SetLog] {
        guard ids.isEmpty == false else { return [] }
        var result: [SetLog] = []
        for id in ids {
            let descriptor = FetchDescriptor<SetLogEntity>(
                predicate: #Predicate { entity in
                    entity.completedAt < date && entity.catalogId == id
                },
                sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
            )
            result += ((try? context.fetch(descriptor)) ?? []).compactMap(Self.log(from:))
        }
        return result
    }

    private static func log(from entity: SetLogEntity) -> SetLog? {
        guard let status = SetStatus(rawValue: entity.statusRaw) else { return nil }
        return SetLog(
            id: entity.id,
            sessionId: entity.sessionId,
            prescriptionId: entity.prescriptionId,
            catalogId: entity.catalogId,
            targetType: entity.targetTypeRaw.flatMap(SetTargetType.init(rawValue:)),
            setIndex: entity.setIndex,
            status: status,
            plannedValue: entity.plannedValue,
            actualValue: entity.actualValue,
            actualLoad: entity.actualLoadValue.flatMap { value in
                entity.actualLoadTypeRaw
                    .flatMap(LoadType.init(rawValue:))
                    .map { Load(type: $0, value: value) }
            },
            swappedFromCatalogId: entity.swappedFromCatalogId,
            predictedValue: entity.predictedValue,
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
