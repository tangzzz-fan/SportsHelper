import Foundation

public enum CustomExerciseId {
    public static func slug(for name: String) -> String {
        let kept = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let cleaned = String(String.UnicodeScalarView(kept))
        return cleaned.isEmpty ? "custom" : String(cleaned.prefix(20))
    }

    public static func id(for name: String) -> String {
        "custom_\(slug(for: name))"
    }
}

public struct UserExercise: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var group: ExerciseGroup
    public var equipment: Equipment
    public var isStatic: Bool
    public var defaultSets: Int
    public var defaultValue: Int
    public var restSec: Int
    public var createdAt: Date

    public init(
        name: String,
        group: ExerciseGroup,
        equipment: Equipment = .bodyweight,
        isStatic: Bool = false,
        defaultSets: Int = 3,
        defaultValue: Int? = nil,
        restSec: Int = 60,
        createdAt: Date = Date()
    ) {
        self.id = CustomExerciseId.id(for: name)
        self.name = name
        self.group = group
        self.equipment = equipment
        self.isStatic = isStatic
        self.defaultSets = defaultSets
        self.defaultValue = defaultValue ?? (isStatic ? 30 : 12)
        self.restSec = restSec
        self.createdAt = createdAt
    }

    public init(
        id: String,
        name: String,
        group: ExerciseGroup,
        equipment: Equipment,
        isStatic: Bool,
        defaultSets: Int,
        defaultValue: Int,
        restSec: Int,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.equipment = equipment
        self.isStatic = isStatic
        self.defaultSets = defaultSets
        self.defaultValue = defaultValue
        self.restSec = restSec
        self.createdAt = createdAt
    }

    public var doseUnit: String {
        isStatic ? "秒" : "次"
    }

    public static func inferEquipment(fromName name: String) -> Equipment {
        if name.contains("壶铃") { return .kettlebell }
        if name.contains("哑铃") { return .dumbbell }
        if name.contains("弹力带") || name.contains("阻力带") { return .band }
        return .bodyweight
    }
}

public struct UserExerciseCatalog: Equatable, Sendable {
    public static let empty = UserExerciseCatalog(exercises: [])

    public var exercises: [UserExercise]

    public init(exercises: [UserExercise]) {
        var seen: Set<String> = []
        self.exercises = exercises.filter { seen.insert($0.id).inserted }
    }

    public func exercise(for id: String) -> UserExercise? {
        exercises.first { $0.id == id }
    }

    public func exercise(named rawName: String) -> UserExercise? {
        let key = ExerciseAliasResolver.normalize(rawName)
        guard !key.isEmpty else { return nil }
        let direct = CustomExerciseId.id(for: rawName)
        if let matched = exercise(for: direct) { return matched }
        return exercises.first { ExerciseAliasResolver.normalize($0.name) == key }
    }

    public var isEmpty: Bool { exercises.isEmpty }

    public func adding(_ exercise: UserExercise) -> UserExerciseCatalog {
        UserExerciseCatalog(exercises: exercises + [exercise])
    }

    public func removing(id: String) -> UserExerciseCatalog {
        UserExerciseCatalog(exercises: exercises.filter { $0.id != id })
    }
}
