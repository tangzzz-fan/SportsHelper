import Foundation
import SwiftData
import DongKeCore

@MainActor
@Observable
final class ProfileStore {
    private let context: ModelContext
    private let key = "profile"
    private(set) var profile: UserProfile?

    init(context: ModelContext) {
        self.context = context
        load()
    }

    var hasOnboarded: Bool {
        profile?.onboardedAt != nil
    }

    func load() {
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.key == "profile" }
        )
        guard let entity = (try? context.fetch(descriptor))?.first,
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: entity.payload) else {
            profile = nil
            return
        }
        profile = decoded
    }

    func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.key == "profile" }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.payload = data
            existing.updatedAt = Date()
        } else {
            context.insert(ProfileEntity(payload: data))
        }
        try? context.save()
        self.profile = profile
    }

    func reset() {
        let descriptor = FetchDescriptor<ProfileEntity>(
            predicate: #Predicate { $0.key == "profile" }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
            try? context.save()
        }
        profile = nil
    }
}
