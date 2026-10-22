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

    public var englishName: String {
        switch self {
        case .monday: "monday"
        case .tuesday: "tuesday"
        case .wednesday: "wednesday"
        case .thursday: "thursday"
        case .friday: "friday"
        case .saturday: "saturday"
        case .sunday: "sunday"
        }
    }

    public init?(name: String) {
        let lowered = name.lowercased()
        guard let value = Weekday.allCases.first(where: { $0.englishName == lowered }) else { return nil }
        self = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            guard let value = Weekday(name: name) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "未知的星期名 \(name)")
            }
            self = value
            return
        }
        let raw = try container.decode(Int.self)
        guard let value = Weekday(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "星期序号须在 1 到 7 之间")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(englishName)
    }

    public var previous: Weekday {
        Weekday(rawValue: rawValue == 1 ? 7 : rawValue - 1) ?? .sunday
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
