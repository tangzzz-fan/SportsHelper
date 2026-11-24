import Foundation

extension SessionLedger {
    /// 把 iPhone 本地日志与 Watch 待同步日志合成一本账。
    ///
    /// 去重键 `(sessionId, setIndex, sourceDevice)`：
    /// - 同一台设备重复写同一组，只留第一条；
    /// - 两台设备各记了同一组，两条都进入账本，再由 `SessionLedger` 自己的去重口径
    ///   （`sessionId + prescriptionId + setIndex + origin`）折叠成一组——完成率不会翻倍。
    ///
    /// 本地（iPhone）日志排在前面，跨设备同组冲突时保留 iPhone 那条。
    public static func merge(
        prescribedSets: Int,
        local: [SetLog],
        remote: [PendingSetLog]
    ) -> SessionLedger {
        SessionLedger(
            prescribedSets: prescribedSets,
            logs: mergedLogs(local: local, remote: remote)
        )
    }

    /// 存储层合并结果。公开 `merge` 只暴露账本计数，测试要看清「设备维度没被误删」
    /// 就得看这一层，所以留模块内可见。
    static func mergedLogs(local: [SetLog], remote: [PendingSetLog]) -> [SetLog] {
        var seen = Set<MergeKey>()
        var merged: [SetLog] = []

        for log in local {
            let key = MergeKey(
                sessionId: log.sessionId,
                setIndex: log.setIndex,
                sourceDevice: .iphone
            )
            if seen.insert(key).inserted {
                merged.append(log)
            }
        }

        for entry in remote.sorted(by: { $0.timestamp < $1.timestamp }) {
            let key = MergeKey(
                sessionId: entry.log.sessionId,
                setIndex: entry.log.setIndex,
                sourceDevice: entry.sourceDevice
            )
            if seen.insert(key).inserted {
                merged.append(entry.log)
            }
        }

        return merged
    }
}

private struct MergeKey: Hashable {
    var sessionId: UUID
    var setIndex: Int
    var sourceDevice: LogSourceDevice
}
