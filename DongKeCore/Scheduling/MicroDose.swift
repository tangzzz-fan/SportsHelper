import Foundation

public struct MicroDose: Equatable, Sendable {
    public var catalogId: String
    public var name: String
    public var sets: Int
    public var seconds: Int
    public var restSec: Int
    public var reason: String

    public var totalSeconds: Int {
        sets * seconds + max(0, sets - 1) * restSec
    }

    public init(
        catalogId: String,
        name: String,
        sets: Int = MicroDosePlanner.sets,
        seconds: Int = MicroDosePlanner.seconds,
        restSec: Int = MicroDosePlanner.restSec,
        reason: String
    ) {
        self.catalogId = catalogId
        self.name = name
        self.sets = sets
        self.seconds = seconds
        self.restSec = restSec
        self.reason = reason
    }
}

public enum MicroDosePlanner {
    public static let sets = 3
    public static let seconds = 40
    public static let restSec = 20

    public static func pick(
        profile: UserProfile,
        plan: WorkoutPlan?,
        on date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> MicroDose? {
        let injuries = BodyPartDetector.parts(in: profile.injuries)
        let available = Set(profile.equipment)
        let planned = Set(
            plan?.days.flatMap { day in
                day.blocks.flatMap { block in block.items.map(\.catalogId) }
            } ?? []
        )

        let candidates = ExerciseLibrary.all.filter { entry in
            entry.purposes.contains(.strength) == false
                && entry.affectedParts.isDisjoint(with: injuries)
                && available.contains(entry.equipment)
        }
        guard candidates.isEmpty == false else { return nil }

        func tier(_ entry: ExerciseEntry) -> (Int, Int, Int, String) {
            let relieved = entry.relievedParts.isDisjoint(with: injuries) ? 1 : 0
            let bodyweight = entry.equipment == .bodyweight ? 0 : 1
            let scheduled = planned.contains(entry.id) ? 1 : 0
            return (relieved, bodyweight, scheduled, entry.id)
        }

        let ordered = candidates.sorted { tier($0) < tier($1) }
        let head = tier(ordered[0])
        let group = ordered.filter {
            let value = tier($0)
            return value.0 == head.0 && value.1 == head.1 && value.2 == head.2
        }
        let seed = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let entry = group[seed % group.count]

        return MicroDose(
            catalogId: entry.id,
            name: entry.name,
            reason: reason(for: entry, injuries: injuries)
        )
    }

    private static func reason(for entry: ExerciseEntry, injuries: Set<BodyPart>) -> String {
        let hit = entry.relievedParts
            .intersection(injuries)
            .sorted { $0.rawValue < $1.rawValue }
            .first
        if let hit { return "\(hit.chineseName)活动" }
        return "\(entry.group.title)活动"
    }
}
