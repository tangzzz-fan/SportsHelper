import Foundation

public enum Weekday: Int, Codable, CaseIterable, Sendable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    public var systemWeekday: Int {
        (rawValue % 7) + 1
    }

    public var chineseName: String {
        switch self {
        case .monday: "周一"
        case .tuesday: "周二"
        case .wednesday: "周三"
        case .thursday: "周四"
        case .friday: "周五"
        case .saturday: "周六"
        case .sunday: "周日"
        }
    }

    public init?(systemWeekday: Int) {
        guard (1...7).contains(systemWeekday) else { return nil }
        let normalized = ((systemWeekday - 2 + 7) % 7) + 1
        self.init(rawValue: normalized)
    }
}
