# 会话快照与待发日志（App Group 本地存储）

状态：Phase 2 实现说明（W2.1 / W2.2）  
上位依据：`docs/specs/IWATCH.md`、`.scratch/iwatch-tickets/TICKETS.md`

---

## 0. 先纠正一个前提：App Group 不是跨设备共享盘

`IWATCH.md` 里「会话日志通过 AppGroups 共享容器双向同步」**不成立**。App Group 容器只在**同一台设备**上的 App 与扩展之间共享；iPhone 与 Watch 是两个设备，各自有独立的文件系统，谁也无法直接读对方 `group.com.dongke.shared` 里的文件。

正确的分工：

| 层 | 机制 | 职责 |
|---|---|---|
| 本地持久化 | App Group 容器（本文件） | 每台设备自己的会话快照 + 待发日志（outbox） |
| 跨设备传输 | WatchConnectivity（`WCSession.transferUserInfo` / `updateApplicationContext`） | 把快照发给 Watch、把组日志发回 iPhone |

所以：**iPhone 写进 App Group 的 checkpoint，Watch 读不到**，必须由传输层发过去。`AppGroupsStore` 只碰本机文件，不要把跨设备逻辑塞进来。W2.3 的「同步」实现时以这个边界为准。

---

## 1. 目录结构

```
group.com.dongke.shared/workouts/
  ├── checkpoint-{sessionId}.json    // 当前会话快照，iPhone 写、训练结束删
  └── pending-logs.jsonl             // 待发组日志，按行追加
```

容器 ID：`group.com.dongke.shared`（`AppGroupsStore.containerID`）。  
入口：`DongKeCore/Data/AppGroupsStore.swift`；会话快照便利层：`DongKeCore/Services/CheckpointStore.swift`。

**前置条件**：App Group 必须在开发者后台注册，并在 target 的 entitlements 里声明。iPhone target 已加 `DongKe/DongKe.entitlements`；Watch target 建好后要加同一个 group。

---

## 2. checkpoint 文件

- 每个会话一个文件，`JSONEncoder` 编码，`.atomic` 写入。
- 训练中每次记组都重写（与 UserDefaults 断点同步发生）；`finishedAt != nil` 时删除。
- `revision` 来自 `plan.revision`；Watch 续练前必须比对，防止拿旧计划继续写日志（W2.5）。
- `revision` / `status` 是 W2.2 新增字段，手写 `init(from:)` 给老断点兜默认值（1 / `.inProgress`），缺字段不能让整条断点在升级后静默消失。

iPhone 侧双写：

| 存储 | 类型 | 用途 |
|---|---|---|
| UserDefaults `dk.workout.checkpoint` | `WorkoutCheckpointStore`（DongKe/Data） | 本机断点续练，杀进程可恢复 |
| App Group `checkpoint-{id}.json` | `CheckpointStore`（DongKeCore） | 交给另一台设备的快照；取不到容器时静默降级 |

「清空全部数据」会调用 `AppGroupsStore.live.clearAll()`，否则重置后 Watch 还能拿到旧快照。

---

## 3. `pending-logs.jsonl`

每行一个 `PendingSetLog`：

```json
{"log":{"actualValue":12,"completedAt":770001234.0,"id":"...","origin":"prescribed","plannedValue":12,"prescriptionId":"i1","sessionId":"...","setIndex":1,"status":"done"},"sourceDevice":"watch","timestamp":770001234.0}
```

`SetLog` 本身没有来源设备字段——来源只属于同步层，不写进 SwiftData，避免为同步给五张表加列。

| 操作 | 实现 | 为什么 |
|---|---|---|
| 追加 | `O_APPEND` + `flock(LOCK_EX)` | 两个进程同时写不会撕行 |
| 读取 | `LOCK_SH` + 按行解码 | 坏行（写到一半被杀）跳过，不能让一行坏数据永久堵住同步 |
| 整份重写 | 同一把排他锁内 `ftruncate` + 写入 | 读—过滤—重写之间不会把别人刚追加的行抹掉 |
| 清空 | 在锁内截断，不删文件 | 另一个进程可能已打开同一 inode，删文件会让它写进「已消失」的文件 |

**已知限制**：重写途中进程崩溃，文件尾部的日志可能丢。当前阶段接受——待发日志在写入前已经落进各自的本地会话快照，丢的是同步副本，不是训练记录。若将来要更强保证，改成「每条日志一个文件」或 SQLite。

---

## 4. 去重与合并

两层，别混：

1. **同步层**（`PendingSetLog`）：键 `(sessionId, setIndex, sourceDevice)`。同一设备重复写同一组只留第一条；两台设备各记了同一组，两条都保留。
2. **账本层**（`SessionLedger.merge`）：`SessionLedger` 自己的键 `(sessionId, prescriptionId, setIndex, origin)` 会把跨设备的同组折叠成一组，完成率不会翻倍。

```swift
let ledger = SessionLedger.merge(
    prescribedSets: day.plannedSets,
    local: iphoneLogs,          // [SetLog]，按 .iphone 标记
    remote: pendingEntries      // [PendingSetLog]，带各自的 sourceDevice
)
```

冲突时本地（iPhone）优先：`mergedLogs` 先放本地，再按 `timestamp` 放远端。iPhone 记了组 2、Watch 也记了组 2，账本保留 iPhone 那条；两边的完成率都以这一条为准。

---

## 5. 版本检查

`WorkoutCheckpoint.matchesRevision(_:)` 是唯一的比对入口。Watch 侧在每次推进前检查：

- 相等 → 允许继续记日志；
- 不等 → 停止写新日志，提示「计划已更新，请返回 iPhone」（W2.5，UI 待 Watch target）。

不要在 Watch 侧用 `plan.revision` 之外的字段（如 `updatedAt`）当版本判据——提醒时间的偏移不改 `revision`，训练中的计划才改。

---

## 6. 测试与未完成

测试（`DongKeCoreTests`，Swift Testing，全部用临时目录注入，不依赖 App Group entitlement）：

- `AppGroupsStoreTests`：快照往返、无容器降级、JSONL 来源与顺序、坏行跳过、条件删除、整份替换/清空、20 路并发追加。
- `WorkoutCheckpointTests`：新字段往返、老断点兜默认值、revision 比对。
- `SessionLedgerMergeTests`：两端不重叠合并、跨设备同组只计一次、同设备重复丢弃、混合状态不丢。

未完成：

- Watch target 尚未创建（Phase 1 W1.1–W1.5 未开工），本文件所有「Watch 侧」行为只有 Core 逻辑与测试，没有 UI。
- WatchConnectivity 传输层未实现；`AppGroupsStore` 与 `CheckpointStore` 只覆盖本机文件。
- 开发者后台的 App Group 注册未验证（真机签名需要）。
