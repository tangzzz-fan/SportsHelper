import Foundation

public enum Muscle: String, CaseIterable, Codable, Sendable, Identifiable {
    case quads
    case hamstrings
    case glutes
    case calves
    case chest
    case back
    case shoulders
    case arms
    case core

    public var id: String { rawValue }

    public var chineseName: String {
        switch self {
        case .quads: "股四头"
        case .hamstrings: "腘绳"
        case .glutes: "臀"
        case .calves: "小腿"
        case .chest: "胸"
        case .back: "背"
        case .shoulders: "肩"
        case .arms: "臂"
        case .core: "核心"
        }
    }
}

public enum PrimaryMuscleMap {
    public static let table: [String: Set<Muscle>] = [
        "squat": [.quads, .glutes],
        "lunge": [.quads, .glutes],
        "glute_bridge": [.glutes],
        "hip_thrust": [.glutes],
        "single_leg_glute_bridge": [.glutes],
        "clamshell": [.glutes],
        "side_lying_leg_raise": [.glutes],
        "wall_sit": [.quads],
        "calf_raise": [.calves],
        "jumping_jack": [.quads],
        "high_knees": [.quads],
        "march_in_place": [.quads],
        "hip_circle": [.glutes],
        "ankle_circle": [.calves],
        "quad_stretch": [.quads],
        "hamstring_stretch": [.hamstrings],
        "hip_flexor_stretch": [.quads],
        "calf_stretch": [.calves],
        "butterfly": [.glutes],
        "dumbbell_rdl": [.hamstrings, .glutes],
        "single_leg_rdl": [.hamstrings, .glutes],
        "single_leg_calf_raise": [.calves],
        "bench_dip": [.arms],

        "push_up": [.chest],
        "dumbbell_row": [.back],
        "shoulder_press": [.shoulders],
        "superman": [.back],
        "arm_circle": [.shoulders],
        "scapular_circle": [.shoulders],
        "chest_stretch": [.chest],
        "neck_stretch": [.shoulders],
        "thread_needle": [.back],
        "dumbbell_bench_press": [.chest],
        "dumbbell_floor_press": [.chest],
        "lateral_raise": [.shoulders],
        "biceps_curl": [.arms],
        "chin_tuck": [.shoulders],
        "scapular_retraction": [.back],
        "wall_slide": [.shoulders],
        "neck_isometric": [.shoulders],

        "bird_dog": [.core],
        "dead_bug": [.core],
        "crunch": [.core],
        "russian_twist": [.core],
        "plank": [.core],
        "side_plank": [.core],
        "mountain_climber": [.core],
        "cat_cow": [.back],
        "back_stretch": [.back],
        "child_pose": [.back],
    ]

    public static func muscles(for id: String) -> Set<Muscle> {
        table[id] ?? []
    }
}

public extension ExerciseEntry {
    var primaryMuscles: Set<Muscle> { PrimaryMuscleMap.muscles(for: id) }

    var primaryMuscleText: String {
        Muscle.allCases
            .filter { primaryMuscles.contains($0) }
            .map(\.chineseName)
            .joined(separator: "、")
    }

    var isStrength: Bool { purposes.contains(.strength) }
}

public enum MuscleCoverage {
    public static func strengthCount(for muscle: Muscle, in entries: [ExerciseEntry] = ExerciseLibrary.all) -> Int {
        entries.filter { $0.isStrength && $0.primaryMuscles.contains(muscle) }.count
    }

    public static func isCovered(_ muscle: Muscle, in entries: [ExerciseEntry] = ExerciseLibrary.all) -> Bool {
        strengthCount(for: muscle, in: entries) >= 2
    }

    public static var uncovered: [Muscle] {
        Muscle.allCases.filter { !isCovered($0) }
    }
}
