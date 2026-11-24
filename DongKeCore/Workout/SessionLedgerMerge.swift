import Foundation
import DongKeCore

extension SessionLedger {
    /// 合并来自 iPhone 与 Watch 的日志
    /// 使用 (sessionId, setIndex, sourceDevice) 三元组去重
    public static func merge(
        local: [SetLog],
        remote: [SetLog]
    ) -> [SetLog] {
        var seen = Set<LogKey>()
        var merged: [SetLog] = []

        // iPhone 日志优先
        for log in local {
            let key = LogKey(sessionId: log.sessionId, setIndex: log.setIndex, sourceDevice: "iphone")
            if seen.insert(key).inserted {
                merged.append(log)
            }
        }

        // Watch 日志追加（不同来源不认为是重复）
        for log in remote {
            let key = LogKey(sessionId: log.sessionId, setIndex: log.setIndex, sourceDevice: "watch")
            if seen.insert(key).inserted {
                merged.append(log)
            }
        }

        // 按 sessionId + setIndex 排序
        merged.sort { a, b in
            if a.sessionId == b.sessionId {
                return a.setIndex < b.setIndex
            }
            return a.sessionId.uuidString < b.sessionId.uuidString
        }

        return merged
    }
}

private struct LogKey: Hashable {
    let sessionId: UUID
    let setIndex: Int
    let sourceDevice: String
}
