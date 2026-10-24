import Foundation
import DongKeCore

@MainActor
@Observable
final class DaySkipStore {
    static let shared = DaySkipStore()

    private let key = "dk.skippedDays"
    private let retentionDays = 120
    private var days: Set<String>

    private init() {
        days = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        prune()
    }

    func isSkipped(_ date: Date = Date()) -> Bool {
        days.contains(Self.key(for: date))
    }

    func skip(_ date: Date = Date()) {
        days.insert(Self.key(for: date))
        prune()
        persist()
    }

    func undo(_ date: Date = Date()) {
        days.remove(Self.key(for: date))
        persist()
    }

    func skippedThisWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = HistoryStats.weekStart(for: now, calendar: calendar)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return days.filter { raw in
            guard let date = Self.date(from: raw) else { return false }
            return date >= start && date < end
        }.count
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        let kept = days.filter { raw in
            guard let date = Self.date(from: raw) else { return false }
            return date >= cutoff
        }
        if kept.count != days.count { days = kept }
    }

    private func persist() {
        UserDefaults.standard.set(Array(days).sorted(), forKey: key)
    }

    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}
