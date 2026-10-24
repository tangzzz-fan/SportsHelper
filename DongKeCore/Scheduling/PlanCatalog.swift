import Foundation

enum PlanCatalog {
    struct Item {
        var id: String
        var name: String
        var equipment: Equipment
        var isStatic: Bool
        var isDynamic: Bool
        var joint: Joint

        enum Joint {
            case lower, upper, core

            init(_ group: ExerciseGroup) {
                switch group {
                case .lower: self = .lower
                case .upper: self = .upper
                case .core: self = .core
                }
            }
        }
    }

    static let items: [Item] = ExerciseLibrary.all
        .filter { $0.purposes.contains(.strength) }
        .map { entry in
            Item(
                id: entry.id,
                name: entry.name,
                equipment: entry.equipment,
                isStatic: entry.isStatic,
                isDynamic: entry.purposes.contains(.warmup),
                joint: Item.Joint(entry.group)
            )
        }

    static func blockedIds(for injuries: String) -> Set<String> {
        let parts = BodyPartDetector.parts(in: injuries)
        guard parts.isEmpty == false else { return [] }
        return Set(
            ExerciseLibrary.all
                .filter { $0.affectedParts.isDisjoint(with: parts) == false }
                .map(\.id)
        )
    }
}
