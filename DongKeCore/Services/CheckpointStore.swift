import Foundation
import DongKeCore

public class CheckpointStore {
    private static let store = AppGroupsStore.shared

    /// 在 iPhone 侧保存当前会话快照
    public static func save(_ checkpoint: WorkoutCheckpoint) throws {
        try store.saveCheckpoint(checkpoint, sessionId: checkpoint.sessionId)
    }

    /// Watch 侧加载会话快照
    public static func load(sessionId: UUID) throws -> WorkoutCheckpoint? {
        return try store.loadCheckpoint(sessionId: sessionId)
    }

    /// 训练结束后清理快照
    public static func remove(sessionId: UUID) throws {
        try store.removeCheckpoint(sessionId: sessionId)
    }

    /// 验证快照版本是否与当前计划匹配
    public static func isRevisionValid(_ checkpoint: WorkoutCheckpoint, currentPlanRevision: Int) -> Bool {
        return checkpoint.revision == currentPlanRevision
    }
}
