import Foundation
import SwiftData

@Model
final class ProfileEntity {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date

    init(key: String = "profile", payload: Data, updatedAt: Date = Date()) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
