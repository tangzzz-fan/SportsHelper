import Foundation
import SwiftData

@Model
final class SessionEntity {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var title: String
    var plannedSets: Int
    var completedSets: Int
    var planDate: Date?
    /// `SessionOrigin` 的 rawValue。nil = 这个字段加上之前记的训练，按手机发起算。
    /// 用 String 而不是 enum：SwiftData 对自定义 Codable 枚举的迁移支持没保证，
    /// 一个可选字符串是确定的轻量迁移。
    var origin: String?

    init(
        id: UUID,
        startedAt: Date,
        finishedAt: Date? = nil,
        title: String,
        plannedSets: Int,
        completedSets: Int,
        planDate: Date? = nil,
        origin: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.title = title
        self.plannedSets = plannedSets
        self.completedSets = completedSets
        self.planDate = planDate
        self.origin = origin
    }
}
