import Foundation

public struct TimeOfDay: Codable, Equatable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public init?(string: String) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        self.hour = hour
        self.minute = minute
    }

    public init?(minutesSinceMidnight minutes: Int) {
        guard (0..<(24 * 60)).contains(minutes) else { return nil }
        self.hour = minutes / 60
        self.minute = minutes % 60
    }

    public var stringValue: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public var minutesSinceMidnight: Int {
        hour * 60 + minute
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
