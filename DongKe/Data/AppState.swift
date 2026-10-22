import Foundation
import DongKeCore

struct SessionSummary: Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var completedSets: Int
    var plannedSets: Int

    var completionRate: Double {
        plannedSets > 0 ? Double(completedSets) / Double(plannedSets) : 0
    }
}

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private(set) var plan: WorkoutPlan = SampleData.plan
    private(set) var completedThisWeek: Int = 2
    private(set) var streakDays: Int = 3
    private(set) var history: [SessionSummary] = AppState.seedHistory

    private init() {}

    var weeklyTarget: Int {
        plan.meta.daysPerWeek
    }

    var weekProgress: Double {
        guard weeklyTarget > 0 else { return 0 }
        return min(1, Double(completedThisWeek) / Double(weeklyTarget))
    }

    func record(_ session: SessionSummary) {
        history.insert(session, at: 0)
        completedThisWeek = min(weeklyTarget, completedThisWeek + 1)
    }

    private static var seedHistory: [SessionSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func offset(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: today) ?? today
        }
        return [
            SessionSummary(date: offset(2), title: "上肢与核心", completedSets: 9, plannedSets: 9),
            SessionSummary(date: offset(4), title: "下肢力量", completedSets: 11, plannedSets: 12),
            SessionSummary(date: offset(7), title: "上肢与核心", completedSets: 6, plannedSets: 9)
        ]
    }
}
