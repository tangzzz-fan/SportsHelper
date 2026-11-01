import Foundation
import SwiftData

@Model
final class MicroDoseEntity {
    @Attribute(.unique) var id: UUID
    var date: Date
    var catalogId: String
    var seconds: Int
    var completed: Bool

    init(id: UUID, date: Date, catalogId: String, seconds: Int, completed: Bool) {
        self.id = id
        self.date = date
        self.catalogId = catalogId
        self.seconds = seconds
        self.completed = completed
    }
}
