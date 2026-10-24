import Foundation
import SwiftData
import DongKeCore

@MainActor
enum DataResetService {
    static let defaultsPrefix = "dk."

    static func clearAll(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        secrets: SecretStoring = KeychainService()
    ) async {
        try? context.delete(model: SetLogEntity.self)
        try? context.delete(model: SessionEntity.self)
        try? context.delete(model: PlanEntity.self)
        try? context.delete(model: ProfileEntity.self)
        try? context.delete(model: UserExerciseEntity.self)
        try? context.save()

        for key in Array(defaults.dictionaryRepresentation().keys) where key.hasPrefix(defaultsPrefix) {
            defaults.removeObject(forKey: key)
        }
        try? secrets.store(nil, for: "ai.apiKey")

        await NotificationService.shared.removeAllOwned()
    }
}
