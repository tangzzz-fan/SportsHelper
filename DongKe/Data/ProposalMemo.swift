import Foundation
import DongKeCore

@MainActor
@Observable
final class ProposalMemo {
    static let shared = ProposalMemo()

    private let key = "dk.dose.memory"
    private let baselineKey = "dk.dose.rebuildBaseline"
    private let defaults: UserDefaults
    private(set) var memory: ProposalMemory
    private(set) var rebuildBaseline: WorkoutPlan?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ProposalMemory.self, from: data) {
            memory = decoded
        } else {
            memory = .empty
        }
        if let data = defaults.data(forKey: baselineKey) {
            rebuildBaseline = try? JSONDecoder().decode(WorkoutPlan.self, from: data)
        }
    }

    func rememberBaseline(_ plan: WorkoutPlan) {
        rebuildBaseline = plan
        guard let data = try? JSONEncoder().encode(plan) else { return }
        defaults.set(data, forKey: baselineKey)
    }

    func clearBaseline() {
        rebuildBaseline = nil
        defaults.removeObject(forKey: baselineKey)
    }

    func accept(_ proposal: PlanProposal, now: Date = Date()) {
        persist(memory.accepting(proposal, now: now))
    }

    func reject(_ proposal: PlanProposal, now: Date = Date()) {
        persist(memory.rejecting(proposal, now: now))
    }

    func settle(with logs: [SetLog]) {
        let next = memory.settling(logs: logs)
        if next != memory { persist(next) }
    }

    func forgetAll() {
        memory = .empty
        rebuildBaseline = nil
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: baselineKey)
    }

    private func persist(_ next: ProposalMemory) {
        memory = next
        guard let data = try? JSONEncoder().encode(next) else { return }
        defaults.set(data, forKey: key)
    }
}
