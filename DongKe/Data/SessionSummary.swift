import Foundation

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
