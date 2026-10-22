import Foundation
import SwiftData
import DongKeCore

@MainActor
@Observable
final class PlanStore {
    private let context: ModelContext
    private(set) var plan: WorkoutPlan?

    init(context: ModelContext) {
        self.context = context
        load()
    }

    func load() {
        let descriptor = FetchDescriptor<PlanEntity>(
            predicate: #Predicate { $0.key == "activePlan" }
        )
        guard let entity = (try? context.fetch(descriptor))?.first,
              let decoded = try? JSONDecoder().decode(WorkoutPlan.self, from: entity.payload) else {
            plan = nil
            return
        }
        plan = decoded
    }

    func save(_ plan: WorkoutPlan) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        let descriptor = FetchDescriptor<PlanEntity>(
            predicate: #Predicate { $0.key == "activePlan" }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.payload = data
            existing.updatedAt = Date()
        } else {
            context.insert(PlanEntity(payload: data))
        }
        try? context.save()
        self.plan = plan
    }

    func clear() {
        let descriptor = FetchDescriptor<PlanEntity>(
            predicate: #Predicate { $0.key == "activePlan" }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
            try? context.save()
        }
        plan = nil
    }
}
