# iWatch Phase 1–2 进展 - 2026-11-24 检查点

**Branch**: `feat/w2-appgroups-sync`  
**阶段**：代码可做的部分基本完成（W1.1/W1.2a/W1.3/W1.4 + W2.1–W2.6）；
剩余是 W1.2 通知深链、后台 flush、真机验收。本机无 watchOS runtime / 开发证书。

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

### W2.3 / W2.6 Core：待发队列与「完成本组」
- `PendingLogQueue` actor（DongKeCore/Watch）：入队、待发数、24h 告警、flush。
- `LogRetryScheduler`：5 → 10 → 30 秒，之后固定 30；成功清零。
- Watch `WatchLogSender`：`WCSession.transferUserInfo` 交棒；未激活抛错、条目保留。
- iPhone `WatchSyncService.didReceiveUserInfo`：解码后写入 iPhone 本机 outbox（不丢日志）。
- Watch `完成本组`：创建 `SetLog`（catalogId/target 来自 `WatchContext`）→ 入队 → 本地推进 →
  有 `restAfterSec` 就进休息；UI 显示「已记录（同步中）」/「待同步（N 组）」。

### W2.4：iPhone 写入门禁
- `WatchLogInbox`：outbox → 活跃会话 / `SetLogStore.addIfAbsent` → 落库成功才删条目。
- `SetLogKey` 公开；`SetLogStore.add` 返回 Bool；按账本键判重。
- 模拟器端到端：写 outbox → 重启 → 日志 +1、outbox 清零；同键不同 id 再写 → 仍 1 条。
- **迁移修复**：SwiftData 默认 `groupContainer: .automatic` 会把整库搬进 App Group；
  已显式 `.none`，见 HANDOFF §6.33。

### W2.5：计划更新冲突检测
- `CheckpointValidator`：notInProgress > planChanged > expired > resumable；
  iPhone 断点续练与 Watch 展示共用同一判断。
- iPhone `WatchSyncService.setPlanRevision`：与 context 同发；AppShell 启动/改版时更新。
- Watch：计划改版显示阻断页；`completeSet` 在非 resumable 时拒绝写日志。
- 已结束/过期/改版三种状态不再显示可操作的训练页。

### 测试
- 新增 47 条（W2.1/W2.2 16 + W1.2a 5 + W2.3 15 + W2.4 2 + W2.5 9），
  `DongKeCoreTests` 全量 **962 条通过**（2026-11-24）。
- 覆盖：快照往返、老格式兜底、无容器降级、来源设备保留、坏行跳过、
  条件删除、整份替换、20 路并发追加、跨设备同组只计一次、同设备重复丢弃。

## ⚠️ 关键结论：App Group 不能跨设备

`IWATCH.md` 写的「Watch 通过 AppGroups 追加到 iPhone」在技术上不成立：
App Group 只在同一台设备内共享，iPhone 与 Watch 的文件系统互不可见。

现在的边界（已按此实现）：

| 层 | 机制 | 状态 |
|---|---|---|
| 每台设备的快照 / outbox | App Group `workouts/` | ✓ W2.1/W2.2 |
| iPhone → Watch 上下文 / planRevision | `WCSession.updateApplicationContext` | ✓ W1.2a/W2.5 |
| Watch → iPhone 组日志 | `WCSession.transferUserInfo` | ✓ W2.3/W2.4 |
| 两端配对收发 | WCSession 真实链路 | 未验（无 runtime / 证书） |

详见 `docs/specs/IWATCH-APPGROUPS.md` §0。

## ✅ 已完成

| Ticket | 内容 | 状态 |
|---|---|---|
| W1.1 | Watch target + 入口 + 路由 | ✓ 编译通过 |
| W1.2a | WatchContext 传输与本地快照 | ✓ 代码完成 |
| W1.3 | Watch 倒计时 UI 与状态机 | ✓ 代码完成 |
| W1.4 | Watch 训练页基础布局 | ✓ 代码完成 |
| W2.1 | App Group 本地存储与文件锁 | ✓ Core + 测试 |
| W2.2 | Checkpoint 序列化与恢复 | ✓ Core + iPhone 双写 |
| W2.3 | 日志队列 / 退避 / WCSession 交棒 | ✓ 代码完成 |
| W2.4 | iPhone 写入门禁 | ✓ 模拟器端到端 |
| W2.5 | 计划版本冲突检测 | ✓ 代码完成 |
| W2.6 | Watch 完成本组 | ✓ 代码完成 |

## 🔄 剩余任务

| 项 | 状态 | 说明 |
|---|---|---|
| W1.2 通知处理与深链 | 未开工 | 排程时没有 `sessionId`，载荷改 dayIndex + planRevision；`WatchRoute` 已留好 |
| W1.5 Phase 1 真机清单 | 阻塞 | 需开发证书 + 配对设备 |
| W2.2 Watch 续练选择 UI | 未做 | 当前直接按缓存显示当前组；ticket 要求的「继续上一组 / 从头开始」选择页没有 |
| W1.3 环形进度（可选） | 待定 | `IWATCH.md` 交付清单写「环形进度」，当前 Watch 是文本倒计时；草图本身没画环 |
| W2.7 Phase 2 真机清单 | 阻塞 | 10 条场景，依赖 W1.5 的前置 |
| 后台定时 flush | 未做 | 当前只有入队立即 flush + 进前台重试 |
| `transferUserInfo` 失败回滚 | 未做 | `didFinishUserInfoTransfer` 错误没有重新入队 |
| Watch-only 日志无活跃会话 | 边缘 | 落 `SetLogStore`，不更新 `SessionEntity`；历史页的「训练天/会话列表」可能少一次 |
| App Group / 签名注册 | 未验证 | 开发者后台未注册 capability |

## 📱 真机验收前置（W1.5 / W2.7 共用）

1. Apple Developer 后台为 `app.dongke.ios` 与 `app.dongke.ios.watchkitapp` 注册 App Group `group.com.dongke.shared`。
2. Watch App ID 开启 Time Sensitive Notifications capability。
3. 本机安装开发证书（当前无证书），或配置自动签名可用的 Apple ID。
4. 配对 Apple Watch Series 9+（或安装 watchOS 27.2 simulator runtime）。
5. 编译/安装：

```bash
xcodegen generate
xcodebuild -project DongKe.xcodeproj -scheme DongKeWatch \
  -destination 'generic/platform=watchOS' build
# 无开发证书时先验编译：加 CODE_SIGNING_ALLOWED=NO
scripts/ui-test.sh   # iOS 侧一条 UI 测试，发布前跑
```

## 📊 度量

| Ticket | 代码 | 单测 | 状态 |
|---|---|---|---|
| W1.1 | DongKeWatch target + 路由 + entitlements | — | ✓ 编译通过 |
| W1.2a | WatchContext + 两端 WCSession + 缓存 | 5 | 代码 ✓，端到端待配对 |
| W1.3 | 倒计时 UI + WatchWorkoutSession | 0（复用 Core 用例） | 代码 ✓，待 runtime 走查 |
| W1.4 | Watch 训练页布局 | 0 | 代码 ✓，待 runtime 检查截断 |
| W2.1 | AppGroupsStore（本机存储） | 8 | Core ✓ |
| W2.2 | WorkoutCheckpoint / CheckpointStore / 双写 | 8（3 + 5） | Core ✓ |
| W2.3 | PendingLogQueue / 退避调度 / WCSession 交棒 | 15 | 代码 ✓，真机待验 |
| W2.4 | WatchLogInbox / 写入门禁 / 账本键去重 | 2（+已有合并用例） | ✓ 模拟器端到端 |
| W2.6 | Watch 完成本组 | 0 | 代码 ✓，真机待验 |
| W2.5 | CheckpointValidator / planRevision 下发 / Watch 阻断 | 9 | 代码 ✓，真机待验 |

**全量单测**：962 / 962 通过  
**已知偏差**：W2.1 验收写「20+ 用例」，当前 W2.1 本身 8 条；W2.3 又补了 15 条队列/退避用例。
按风险点覆盖，不追数字。W1.5 / W2.7 的真机项全部未验。
