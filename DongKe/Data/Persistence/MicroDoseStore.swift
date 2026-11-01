import Foundation
import SwiftData
import DongKeCore

@MainActor
@Observable
final class MicroDoseStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func log(_ dose: MicroDose, seconds: Int, completed: Bool, at date: Date = Date()) {
        context.insert(MicroDoseEntity(
            id: UUID(),
            date: date,
            catalogId: dose.catalogId,
            seconds: seconds,
            completed: completed
        ))
        try? context.save()
    }

    func deleteAll() {
        try? context.delete(model: MicroDoseEntity.self)
        try? context.save()
    }
}
