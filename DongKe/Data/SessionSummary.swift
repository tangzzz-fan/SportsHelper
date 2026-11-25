import Foundation
import DongKeCore

struct SessionSummary: Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var completedSets: Int
    var plannedSets: Int
    var planDate: Date?
    /// nil = 这个字段加上之前记的训练。
    var origin: SessionOrigin?

    var completionRate: Double {
        HistoryStats.rate(completedSets, of: plannedSets) ?? 0
    }
}
