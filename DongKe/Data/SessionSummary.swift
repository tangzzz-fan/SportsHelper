import Foundation
import DongKeCore

struct SessionSummary: Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var completedSets: Int
    var plannedSets: Int
    var planDate: Date?

    var completionRate: Double {
        HistoryStats.rate(completedSets, of: plannedSets) ?? 0
    }
}
