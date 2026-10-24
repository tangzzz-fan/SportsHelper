import Foundation

public enum ExerciseGroup: String, CaseIterable, Sendable {
    case lower
    case upper
    case core

    public var title: String {
        switch self {
        case .lower: "下肢"
        case .upper: "上肢"
        case .core: "核心"
        }
    }
}

public struct ExerciseEntry: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var group: ExerciseGroup
    public var equipment: Equipment
    public var isStatic: Bool
    public var cues: [String]
    public var mistakes: [String]
    public var regressionName: String
    public var regressionId: String?
    public var affectedParts: Set<BodyPart>
    public var purposes: Set<ExercisePurpose>

    public init(
        id: String,
        name: String,
        group: ExerciseGroup,
        equipment: Equipment,
        isStatic: Bool,
        cues: [String],
        mistakes: [String],
        regressionName: String,
        regressionId: String? = nil,
        affectedParts: Set<BodyPart> = [],
        purposes: Set<ExercisePurpose> = [.strength]
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.equipment = equipment
        self.isStatic = isStatic
        self.cues = cues
        self.mistakes = mistakes
        self.regressionName = regressionName
        self.regressionId = regressionId
        self.affectedParts = affectedParts
        self.purposes = purposes
    }

    public var tagText: String {
        isStatic ? "静力 · \(equipment.chineseName)" : equipment.chineseName
    }
}

public enum ExerciseLibrary {
    public static let all: [ExerciseEntry] = lowerEntries + upperEntries + coreEntries

    public static func entry(for id: String, merging map: ExerciseMergeMap = .current) -> ExerciseEntry? {
        let key = map.resolve(id)
        return all.first { $0.id == key }
    }

    public static var identifiers: Set<String> {
        Set(all.map(\.id))
    }

    public static func grouped() -> [(group: ExerciseGroup, entries: [ExerciseEntry])] {
        ExerciseGroup.allCases.map { group in
            (group, all.filter { $0.group == group })
        }
    }
}
