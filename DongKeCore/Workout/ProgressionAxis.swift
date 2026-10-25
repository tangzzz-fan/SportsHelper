import Foundation

public enum ProgressionAxis: Equatable, Sendable {
    case reps
    case holdSeconds

    public static let holdStep = 5
    public static let holdCeiling = 60
    public static let holdFloor = 5

    public init?(_ target: SetTarget) {
        switch target.type {
        case .reps: self = .reps
        case .durationSec: self = .holdSeconds
        case .distanceM: return nil
        }
    }

    public var field: PlanProposal.Change.Field {
        switch self {
        case .reps: .reps
        case .holdSeconds: .hold
        }
    }

    public func raised(_ value: Int) -> Int? {
        switch self {
        case .reps:
            let next = value + DoseAdjustment.repStep
            guard next <= DoseAdjustment.repCeiling else { return nil }
            return next
        case .holdSeconds:
            let next = value + Self.holdStep
            guard next <= Self.holdCeiling else { return nil }
            return next
        }
    }

    public func eased(_ value: Int) -> Int? {
        switch self {
        case .reps:
            let next = max(DoseAdjustment.repFloor, value - DoseAdjustment.repStep)
            guard next < value else { return nil }
            return next
        case .holdSeconds:
            let next = max(Self.holdFloor, value - Self.holdStep)
            guard next < value else { return nil }
            return next
        }
    }

    public func softened(_ value: Int, factor: Double) -> Int? {
        switch self {
        case .reps:
            let next = max(DoseAdjustment.repFloor, Int((Double(value) * factor).rounded()))
            guard next < value else { return nil }
            return next
        case .holdSeconds:
            let raw = Int((Double(value) * factor).rounded())
            let stepped = (raw / Self.holdStep) * Self.holdStep
            let next = max(Self.holdFloor, stepped)
            guard next < value else { return nil }
            return next
        }
    }
}
