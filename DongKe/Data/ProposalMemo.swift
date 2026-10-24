import Foundation
import DongKeCore

@MainActor
@Observable
final class ProposalMemo {
    static let shared = ProposalMemo()

    private let key = "dk.dose.rejected"
    private let defaults: UserDefaults
    private(set) var rejected: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rejected = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isRejected(_ proposal: PlanProposal) -> Bool {
        rejected.contains(proposal.fingerprint)
    }

    func rememberRejection(_ proposal: PlanProposal) {
        rejected.insert(proposal.fingerprint)
        defaults.set(rejected.sorted(), forKey: key)
    }

    func forgetAll() {
        rejected = []
        defaults.removeObject(forKey: key)
    }
}
