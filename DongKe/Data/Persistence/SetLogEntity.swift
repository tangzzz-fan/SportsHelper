import Foundation
import SwiftData

@Model
final class SetLogEntity {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var prescriptionId: String
    var setIndex: Int
    var statusRaw: String
    var plannedValue: Int
    var actualValue: Int
    var skipReasonRaw: String?
    var completedAt: Date
    var rpe: Int?

    init(
        id: UUID,
        sessionId: UUID,
        prescriptionId: String,
        setIndex: Int,
        statusRaw: String,
        plannedValue: Int,
        actualValue: Int,
        skipReasonRaw: String?,
        completedAt: Date,
        rpe: Int? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.prescriptionId = prescriptionId
        self.setIndex = setIndex
        self.statusRaw = statusRaw
        self.plannedValue = plannedValue
        self.actualValue = actualValue
        self.skipReasonRaw = skipReasonRaw
        self.completedAt = completedAt
        self.rpe = rpe
    }
}
