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
            SessionRecordSummary(date: $0.date, plannedSets: $0.plannedSets, completedSets: $0.completedSets)
        }
    }

    var completedThisWeek: Int {
        HistoryStats.completedThisWeek(summaries, now: Date())
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
                plannedSets: $0.plannedSets
            )
        }
    }

    func upsert(
        id: UUID,
        title: String,
        plannedSets: Int,
        completedSets: Int,
        startedAt: Date,
        finishedAt: Date? = nil
    ) {
        if let existing = entity(with: id) {
            existing.completedSets = completedSets
            existing.plannedSets = plannedSets
            if let finishedAt {
                existing.finishedAt = finishedAt
            }
        } else {
            context.insert(SessionEntity(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                title: title,
                plannedSets: plannedSets,
                completedSets: completedSets
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
