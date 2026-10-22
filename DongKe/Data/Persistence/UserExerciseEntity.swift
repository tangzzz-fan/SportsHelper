import Foundation
import SwiftData

@Model
final class UserExerciseEntity {
    @Attribute(.unique) var exerciseId: String
    var name: String
    var groupRaw: String
    var equipmentRaw: String
    var isStatic: Bool
    var defaultSets: Int
    var defaultValue: Int
    var restSec: Int
    var createdAt: Date

    init(
        exerciseId: String,
        name: String,
        groupRaw: String,
        equipmentRaw: String,
        isStatic: Bool,
        defaultSets: Int,
        defaultValue: Int,
        restSec: Int,
        createdAt: Date = Date()
    ) {
        self.exerciseId = exerciseId
        self.name = name
        self.groupRaw = groupRaw
        self.equipmentRaw = equipmentRaw
        self.isStatic = isStatic
        self.defaultSets = defaultSets
        self.defaultValue = defaultValue
        self.restSec = restSec
        self.createdAt = createdAt
    }
}
