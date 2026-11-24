# Phase 2 进展 - 2026-11-24 检查点

**Branch**: `feat/w2-appgroups-sync`  
**阶段**：W2.1 / W2.2 Core 侧完成；W1.1 Watch target + W1.2a 上下文传输完成（端到端待配对设备）

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

### W1.1：Watch target 与基础路由
- `DongKeCore` 改为 `platform: auto` + `supportedDestinations: [iOS, watchOS]`：
  一份 Foundation 源码出两个平台，Watch 不再维护第二份 Core。
- 新增 `DongKeWatch` target（watchOS 11.0）、`WatchApp.swift`、`RootView.swift`
  （`WatchRoute.workout(sessionId:)` 路由），只 import SwiftUI + DongKeCore。
- Watch entitlements：App Group + Time Sensitive Notifications。
- XcodeGen 自动把 `DongKeWatch.app` 嵌进 iOS app 的 `Watch/`（Embed Watch Content）。
- 编译验证：watchOS Simulator SDK、watchOS 设备 SDK（`CODE_SIGNING_ALLOWED=NO`）均通过；
  iOS 构建与 931 条单测不受影响。
- **未过**：真机签名。本机无开发证书，且开发者后台未注册 App Group / Time Sensitive。

### W1.2a：WatchContext 传输与本地快照
- `DongKeCore/Watch/WatchContext.swift`：`checkpoint` + 当天标题 + 动作展示表
  （名字 / 总组数 / 目标文案 / 休息），`make(checkpoint:plan:)` 从计划派生。
- iPhone `WatchSyncService`：WCSession 激活、保留最后一份上下文、激活后补发；
  `WorkoutSession.saveCheckpoint` 在训练开始 / 记组 / 休息变化 / 结束时发送。
- Watch `WatchSyncService`：收 `applicationContext` → 解码 → `WatchContextStore`
  落盘 → `WatchContextModel` 更新；冷启动先读缓存。
- Watch 首页显示标题 / 动作 / 第 N 组 / 目标。
- 坑一：Watch bundle id 必须是 iOS bundle id 的子前缀，已改为 `app.dongke.ios.watchkitapp`。
- 坑二：训练开始时原本不存 checkpoint，第一组记完前 Watch 收不到；`WorkoutView.onAppear` 补一次。

### W1.3：Watch 倒计时 UI 与状态机
- `WatchWorkoutSession`：`RestTimerStateMachine` 驱动，视图每 0.25s tick；
  回到前台按绝对时间重算；上下文只在新 `updatedAt` 时覆盖本地休息状态。
- `WatchRestView`：动作名 + 第 N 组 / 共 M 组、88pt 倒计时、+15 秒、完成本组；
  VoiceOver 值按 10 秒取整并主动播报。
- `RootView` 在休息时切到倒计时页；`DK_WATCH_DEMO_REST=1` 供 DEBUG 截图。
- 已有 Core 用例 `backgroundJumpFinishesInSingleTick` 覆盖跨 10 分钟回前台。

### W1.4：Watch 训练页基础布局
- `WatchWorkoutView`：当天标题 / 动作名 / 第 N 组共 M 组 / 目标（含「每侧」）/ 完成按钮；
  休息中自动切换 `WatchRestView`；无骨架、要点、常见错误。
- 整页合并为一个无障碍元素：「动作，第 N 组，共 M 组，目标 X」。
- Phase 1 的「完成本组」禁用，页面注明「本组在 iPhone 上记录」；W2.6 打开并接日志回传。

### 测试
- 新增 21 条（W2.1/W2.2 16 条 + W1.2a 5 条），`DongKeCoreTests` 全量 **936 条通过**（2026-11-24）。
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
| W1.1 | Watch target + 入口 + 路由 | ✓ 已完成（2026-11-24） |
| W1.2a | WatchContext 传输与本地快照 | ✓ 代码完成；端到端待配对设备 |
| W1.2 | 通知处理与深链 | 载荷无 `sessionId`，改用 dayIndex + context revision |
| W1.3 | Watch 倒计时 UI 与状态机 | 代码完成；待 runtime/真机走查 |
| W1.4 | Watch 训练页基础布局 | 代码完成；待 runtime 检查截断 |
| W1.3–W1.5 | 倒计时、执行页、真机清单 | 待做；真机签名需先注册 App Group 与 Time Sensitive 能力 |
| W2.3 | Watch 日志队列与指数退避重试 | 需要 WCSession 传输层；Watch target 已就绪 |
| W2.4 | iPhone 侧日志合并写入门禁 | Core 合并已就绪；SwiftData 接线待 WCSession 有数据来源 |
| W2.5 | 计划更新冲突检测 | `matchesRevision` 已就绪；Watch UI 待 W1.3/W1.4 |
| W2.6 | Watch 完成组 UI | 依赖 W1.4 |
| W2.7 | 真机验收 | 依赖 W2.3–W2.6 |

## 📊 度量

| Ticket | 代码 | 单测 | 状态 |
|---|---|---|---|
| W1.1 | DongKeWatch target + 路由 + entitlements | — | ✓ 编译通过 |
| W1.2a | WatchContext + 两端 WCSession + 缓存 | 5 | 代码 ✓，端到端待配对 |
| W1.3 | 倒计时 UI + WatchWorkoutSession | 0（复用 Core 用例） | 代码 ✓，待 runtime 走查 |
| W1.4 | Watch 训练页布局 | 0 | 代码 ✓，待 runtime 检查截断 |
| W2.1 | AppGroupsStore（本机存储） | 8 | Core ✓ |
| W2.2 | WorkoutCheckpoint / CheckpointStore / 双写 | 8（3 + 5） | Core ✓ |
| W2.3–W2.7 | — | — | 待 W1.2–W1.5 / 日志回传 |

**全量单测**：936 / 936 通过  
**已知偏差**：W2.1 验收写「20+ 用例」，当前 16 条；先覆盖已实现的风险点，剩余随 W2.3 的队列/重试一起补。
