import Foundation
import SwiftData
import DongKeCore

@MainActor
@Observable
final class UserExerciseStore {
    private let context: ModelContext
    private(set) var catalog: UserExerciseCatalog = .empty

    init(context: ModelContext) {
        self.context = context
        load()
    }

    var all: [UserExercise] { catalog.exercises }

    func load() {
        let descriptor = FetchDescriptor<UserExerciseEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        catalog = UserExerciseCatalog(exercises: entities.map { entity in
            UserExercise(
                id: entity.exerciseId,
                name: entity.name,
                group: ExerciseGroup(rawValue: entity.groupRaw) ?? .lower,
                equipment: Equipment(rawValue: entity.equipmentRaw) ?? .bodyweight,
                isStatic: entity.isStatic,
                defaultSets: entity.defaultSets,
                defaultValue: entity.defaultValue,
                restSec: entity.restSec,
                createdAt: entity.createdAt
            )
        })
    }

    func exercise(for id: String) -> UserExercise? {
        catalog.exercise(for: id)
    }

    @discardableResult
    func add(_ exercise: UserExercise) -> UserExercise {
        let targetId = exercise.id
        let descriptor = FetchDescriptor<UserExerciseEntity>(
            predicate: #Predicate { $0.exerciseId == targetId }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.name = exercise.name
            existing.groupRaw = exercise.group.rawValue
            existing.equipmentRaw = exercise.equipment.rawValue
            existing.isStatic = exercise.isStatic
            existing.defaultSets = exercise.defaultSets
            existing.defaultValue = exercise.defaultValue
            existing.restSec = exercise.restSec
        } else {
            context.insert(UserExerciseEntity(
                exerciseId: exercise.id,
                name: exercise.name,
                groupRaw: exercise.group.rawValue,
                equipmentRaw: exercise.equipment.rawValue,
                isStatic: exercise.isStatic,
                defaultSets: exercise.defaultSets,
                defaultValue: exercise.defaultValue,
                restSec: exercise.restSec,
                createdAt: exercise.createdAt
            ))
        }
        try? context.save()
        load()
        return exercise
    }

    func remove(id: String) {
        let targetId = id
        let descriptor = FetchDescriptor<UserExerciseEntity>(
            predicate: #Predicate { $0.exerciseId == targetId }
        )
        guard let entity = (try? context.fetch(descriptor))?.first else { return }
        context.delete(entity)
        try? context.save()
        load()
    }
}
