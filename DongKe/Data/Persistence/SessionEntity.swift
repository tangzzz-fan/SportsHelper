import Foundation
import SwiftData

@Model
final class SessionEntity {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var title: String
    var plannedSets: Int
    var completedSets: Int

    init(
        id: UUID,
        startedAt: Date,
        finishedAt: Date? = nil,
        title: String,
        plannedSets: Int,
        completedSets: Int
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.title = title
        self.plannedSets = plannedSets
        self.completedSets = completedSets
    }
}
