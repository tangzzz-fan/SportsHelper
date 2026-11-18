import Foundation
import SwiftData

@Model
final class SetLogEntity {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var prescriptionId: String
    var catalogId: String?
    var targetTypeRaw: String?
    var setIndex: Int
    var statusRaw: String
    var plannedValue: Int
    var actualValue: Int
    var actualLoadValue: Double?
    var actualLoadTypeRaw: String?
    var swappedFromCatalogId: String?
    var predictedValue: Int?
    var skipReasonRaw: String?
    var completedAt: Date
    var rpe: Int?
    var originRaw: String?

    init(
        id: UUID,
        sessionId: UUID,
        prescriptionId: String,
        catalogId: String? = nil,
        targetTypeRaw: String? = nil,
        setIndex: Int,
        statusRaw: String,
        plannedValue: Int,
        actualValue: Int,
        actualLoadValue: Double? = nil,
        actualLoadTypeRaw: String? = nil,
        swappedFromCatalogId: String? = nil,
        predictedValue: Int? = nil,
        skipReasonRaw: String?,
        completedAt: Date,
        rpe: Int? = nil,
        originRaw: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.prescriptionId = prescriptionId
        self.catalogId = catalogId
        self.targetTypeRaw = targetTypeRaw
        self.setIndex = setIndex
        self.statusRaw = statusRaw
        self.plannedValue = plannedValue
        self.actualValue = actualValue
        self.actualLoadValue = actualLoadValue
        self.actualLoadTypeRaw = actualLoadTypeRaw
        self.swappedFromCatalogId = swappedFromCatalogId
        self.predictedValue = predictedValue
        self.skipReasonRaw = skipReasonRaw
        self.completedAt = completedAt
        self.rpe = rpe
        self.originRaw = originRaw
    }
}
