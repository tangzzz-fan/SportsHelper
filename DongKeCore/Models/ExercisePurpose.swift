import Foundation

public enum ExercisePurpose: String, CaseIterable, Codable, Sendable, Identifiable {
    case warmup
    case strength
    case stretch
    case mobility

    public var id: String { rawValue }

    public var chineseName: String {
        switch self {
        case .warmup: "热身"
        case .strength: "力量"
        case .stretch: "拉伸"
        case .mobility: "活动度"
        }
    }
}
