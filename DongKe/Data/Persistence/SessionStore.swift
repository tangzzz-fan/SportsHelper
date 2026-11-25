import Foundation
import SwiftData
import DongKeCore

@MainActor
@Observable
final class SessionStore {
    private let context: ModelContext
    private(set) var sessions: [SessionSummary] = []

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    var summaries: [SessionRecordSummary] {
        sessions.map {
            SessionRecordSummary(
                date: $0.date,
                plannedSets: $0.plannedSets,
                completedSets: $0.completedSets,
                planDate: $0.planDate
            )
        }
    }

    var completedDaysThisWeek: Int {
        HistoryStats.completedDaysThisWeek(summaries, now: Date())
    }

    var streakDays: Int {
        HistoryStats.streak(summaries, now: Date())
    }

    func reload() {
        let descriptor = FetchDescriptor<SessionEntity>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let entities = (try? context.fetch(descriptor)) ?? []
        sessions = entities.map {
            SessionSummary(
                id: $0.id,
                date: $0.startedAt,
                title: $0.title,
                completedSets: $0.completedSets,
                plannedSets: $0.plannedSets,
                planDate: $0.planDate,
                origin: $0.origin.flatMap(SessionOrigin.init(rawValue:))
            )
        }
    }

    func upsert(
        id: UUID,
        title: String,
        plannedSets: Int,
        completedSets: Int,
        startedAt: Date,
        finishedAt: Date? = nil,
        planDate: Date? = nil,
        origin: SessionOrigin? = nil
    ) {
        if let existing = entity(with: id) {
            existing.completedSets = completedSets
            existing.plannedSets = plannedSets
            if let finishedAt {
                existing.finishedAt = finishedAt
            }
            if let planDate {
                existing.planDate = planDate
            }
            // 续练时不知道原始来源，传 nil 就别把已有值冲掉。
            if let origin {
                existing.origin = origin.rawValue
            }
        } else {
            context.insert(SessionEntity(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                title: title,
                plannedSets: plannedSets,
                completedSets: completedSets,
                planDate: planDate,
                origin: origin?.rawValue
            ))
        }
        try? context.save()
        reload()
    }

    private func entity(with id: UUID) -> SessionEntity? {
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }
}
