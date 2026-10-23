import Foundation

public enum SetTargetType: String, Codable, Sendable {
    case reps
    case durationSec = "duration_sec"
    case distanceM = "distance_m"
}

public struct SetTarget: Codable, Equatable, Sendable {
    public var type: SetTargetType
    public var value: Int
    public var perSide: Bool

    public init(type: SetTargetType, value: Int, perSide: Bool) {
        self.type = type
        self.value = value
        self.perSide = perSide
    }
}

public extension SetTarget {
    var doseText: String {
        switch type {
        case .reps:
            return "\(value) 次"
        case .durationSec:
            return "\(value) 秒"
        case .distanceM:
            guard value >= 1000 else { return "\(value) 米" }
            let kilometers = Double(value) / 1000
            return kilometers == kilometers.rounded()
                ? "\(Int(kilometers)) 公里"
                : String(format: "%.1f 公里", kilometers)
        }
    }

    var estimatedWorkSeconds: Int {
        switch type {
        case .reps:
            return value * 3
        case .durationSec:
            return value
        case .distanceM:
            return Int(Double(value) * 0.4)
        }
    }
}
