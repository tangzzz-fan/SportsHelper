# Phase 2 进展 - 2026-11-24 检查点

**Branch**: `feat/w2-appgroups-sync`  
**阶段**：W2.1 / W2.2 的 Core 侧完成并通过测试；Watch target 仍未创建

## 先修正上一份检查点

上一版写着「W2.1 & W2.2 完成」，但那次提交有两个硬问题：

1. 新增文件没有进 `DongKe.xcodeproj`（提交里没有 `project.pbxproj`），**从未编译过**；
2. 重新生成工程后立刻失败：`DongKeCore/Models/WorkoutCheckpoint.swift` 与 `WorkoutCheckpoint/` 里已有的同名类型重复；新测试用的 `SetLog(sessionId:setIndex:reps:unit:rpe:)` 构造器也不存在。

这一轮把它们修到「能编译、能测试、口径自洽」，并补上了漏掉的文档。

## ✅ 本轮完成

### W2.1：App Group 本地存储与文件锁
- `DongKeCore/Data/AppGroupsStore.swift`
  - 容器 URL 可注入（测试用临时目录，不依赖 entitlement）
  - checkpoint 原子写 / 读 / 删
  - JSON Lines 追加：`O_APPEND` + `flock(LOCK_EX)`；读取用共享锁
  - 坏行跳过；条件删除在锁内读—过滤—重写；清空用截断而非删文件
  - `PendingSetLog` 保留 `sourceDevice` 与 `timestamp`
- `DongKe/DongKe.entitlements` + `project.yml`：iPhone target 声明 `group.com.dongke.shared`
- 文档：`docs/specs/IWATCH-APPGROUPS.md`

### W2.2：Checkpoint 序列化与恢复（Core）
- 合并为**一个** `WorkoutCheckpoint`，新增 `revision` / `status`
- 手写 `init(from:)`：老断点缺新字段时兜默认值，升级不丢断点
- `CheckpointStore`（DongKeCore）改为实例 + 注入
- iPhone 接线：`WorkoutSession.saveCheckpoint` 双写 UserDefaults + App Group；
  训练结束、清空全部数据时同步清理 App Group
- `SessionLedger.merge(prescribedSets:local:remote:)`：按
  `(sessionId, setIndex, sourceDevice)` 去重，再交给账本按自己的口径折叠

### 测试
- 新增 16 条，`DongKeCoreTests` 全量 **931 条通过**（2026-11-24）。
- 覆盖：快照往返、老格式兜底、无容器降级、来源设备保留、坏行跳过、
  条件删除、整份替换、20 路并发追加、跨设备同组只计一次、同设备重复丢弃。

## ⚠️ 关键结论：App Group 不能跨设备

`IWATCH.md` 写的「Watch 通过 AppGroups 追加到 iPhone」在技术上不成立：
App Group 只在同一台设备内共享，iPhone 与 Watch 的文件系统互不可见。

现在的边界：

| 层 | 机制 |
|---|---|
| 每台设备的快照 / outbox | App Group（本分支已做） |
| iPhone ↔ Watch 传输 | WatchConnectivity（WCSession），**未实现** |

W2.3 的「同步与重试」必须在 WCSession 之上做，不能继续往 `AppGroupsStore` 里加跨设备逻辑。详见 `docs/specs/IWATCH-APPGROUPS.md` §0。

## 🔄 待办

| Ticket | 内容 | 阻塞点 |
|---|---|---|
| W1.1–W1.5 | Watch target、通知、倒计时、执行页、真机清单 | **未开工**，W2.3/W2.6 都依赖它 |
| W2.3 | Watch 日志队列与指数退避重试 | 需要 Watch target + WCSession 传输层 |
| W2.4 | iPhone 侧日志合并写入门禁 | Core 合并已就绪；SwiftData 接线待 WCSession 有数据来源 |
| W2.5 | 计划更新冲突检测 | `matchesRevision` 已就绪；Watch UI 待 target |
| W2.6 | Watch 完成组 UI | 依赖 W1.1 |
| W2.7 | 真机验收 | 依赖 W2.3–W2.6 |

## 📊 度量

| Ticket | 代码 | 单测 | 状态 |
|---|---|---|---|
| W2.1 | AppGroupsStore（本机存储） | 8 | Core ✓ |
| W2.2 | WorkoutCheckpoint / CheckpointStore / 双写 | 8（3 + 5） | Core ✓ |
| W2.3–W2.7 | — | — | 待 Watch target |

**全量单测**：931 / 931 通过  
**已知偏差**：W2.1 验收写「20+ 用例」，当前 16 条；先覆盖已实现的风险点，剩余随 W2.3 的队列/重试一起补。
