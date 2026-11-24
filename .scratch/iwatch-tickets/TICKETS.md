# iWatch 实现 Tickets

## Phase 1：通知 + 倒计时（MVP 验证）

---

### 📋 TICKET-W1.1：Watch target 创建 & 基础架构

**优先级**：P0 | **工时**：1 人日 | **阶段**：Phase 1 start  
**相关**：ADR-0001  

**描述**：
创建 `DongKeWatch` target（SwiftOS 应用），建立基础代码结构与依赖关系。

**交付物**：
- [x] 新增 `DongKeWatch` target（XcodeGen：`project.yml`）
- [x] 添加 Entitlements（AppGroups + Time Sensitive Notifications）
- [x] `WatchApp.swift` 入口（@main）
- [x] `RootView.swift` 路由分发（`WatchRoute.workout(sessionId:)`）
- [x] 确保编译通过（先不跑功能）

**验收**：
```bash
xcodebuild -scheme DongKeWatch -destination 'generic/platform=watchos' build
# ✓ Build succeeded（需本机签名；无证书时加 CODE_SIGNING_ALLOWED=NO 验编译）
```

**2026-11-24 落地说明**：
- `DongKeCore` 改为 `platform: auto` + `supportedDestinations: [iOS, watchOS]`，一份源码出两个平台；Watch app 嵌入 iOS app 的 `Watch/` 目录（XcodeGen 自动生成 Embed Watch Content）。
- `watchOS 11.0` / iOS 18.0；Watch 只 import SwiftUI + DongKeCore，不 import SwiftData。
- 模拟器与设备 SDK（`CODE_SIGNING_ALLOWED=NO`）均编译通过；iOS 931 条单测仍全绿。
- **真机签名未过**：本机无开发证书，且开发者后台未注册 `group.com.dongke.shared` 与 Time Sensitive 能力。这是 W1.5 真机验收的前置项。

**设计决策**：
- Watch App 仅 import DongKeCore + SwiftUI，不 import SwiftData
- 通知处理走 `UNUserNotificationCenterDelegate`

---

### 📋 TICKET-W1.2a：WatchContext 传输与本地快照（前置）

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 1，W1.2 之前  
**相关**：SPEC §2、§5；ADR-0004

**为什么加这张票**：

W1.2–W1.4 都假设 Watch 知道「当前第几组、目标多少、下一个动作是什么」，但 Watch 上没有计划、没有档案、没有 SwiftData。现有 tickets 没有任何一张负责把这份上下文送过去；`IWATCH.md` 的 App Group 方案又不能跨设备。**不先解决它，W1.2 的深链与 W1.4 的训练页都没有数据可显示。**

另外，iPhone 的提醒是**提前排程**的，排程时本次训练会话还没创建——所以 `W1.2` 里写的 `userInfo["sessionId"]` 不存在。载荷只能带 `dayIndex` / weekday，或等会话开始后另发一次上下文。

**交付物**：
- [x] `WatchContext: Codable, Sendable`（`DongKeCore/Watch/WatchContext.swift`）
  - `checkpoint`（步骤/日志/休息/版本）+ `dayTitle` + `[prescriptionId: WatchExerciseInfo]`
  - `WatchExerciseInfo`：动作名、总组数、目标文案、休息秒数
  - `WatchContext.make(checkpoint:plan:)` 从会话快照与计划派生
- [x] iPhone `WatchSyncService`（`DongKe/Services`）
  - 持有 `WCSession`，App 启动时 `activate()`；保留最后一份上下文，激活后补发
  - `WorkoutSession.saveCheckpoint` 在训练开始（WorkoutView.onAppear）、每次记组、休息变化、结束时发送
  - `WorkoutCheckpoint.status = .completed` 作为结束信号
- [x] Watch `WatchContextStore`（`DongKeCore/Services`，App Group 文件 `watch-context.json`）
  - 收包后落盘；`WatchRootView` 冷启动先 `loadFromCache`
  - `WatchSyncService`（Watch target）在 `didReceiveApplicationContext` 解码并更新 `WatchContextModel`
- [x] Watch 首页显示缓存内容（标题 / 动作 / 第 N 组 / 目标）
- [ ] Watch 侧日志回传边界（`PendingSetLog` → `transferUserInfo`）留给 W2.3

**验收**：
- [x] 单测：`WatchContext` 派生、当前步骤、往返编码、缓存读写（5 条）
- [x] 两端编译通过（watchOS Simulator / 设备 SDK 免签；iOS build-for-testing）
- [x] iOS 模拟器启动正常，WCSession 激活日志无崩溃（未配对时 `paired: NO` 属预期）
- [ ] 真机（或装好 watchOS runtime 的模拟器）配对后，iPhone 开始训练 1 秒内 Watch 能读到上下文
- [ ] 关掉 iPhone 后，Watch 仍能用缓存显示最后一组

**落地时发现的坑**：
- Watch app 的 bundle id 必须是 iOS app bundle id 的**子前缀**，否则安装直接报错；已改为 `app.dongke.ios.watchkitapp`。
- 训练开始时原本没有 `saveCheckpoint` 调用，第一组记完前 Watch 收不到上下文；现在 `WorkoutView.onAppear` 会主动存一次。

**已知环境**：本机未安装 watchOS simulator runtime，也没有开发证书；端到端验收只能等真机或下载 runtime。

---

### 📋 TICKET-W1.2：通知处理与深链

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 1  
**相关**：SPEC §3、SPEC §6

**描述**：
实现从 iPhone 侧到 Watch 侧的通知流，包括消息解析、Deep link 处理。

> **前置修正（2026-11-24）**：先做 W1.2a。提醒是提前排程的，排程时没有 `sessionId`，`userInfo["sessionId"]` 这条不成立；改为 `dayIndex` + `WatchContext` 的 `revision`，会话内的 `sessionId` 由上下文快照携带。

**交付物**：
- [ ] `WatchNotificationHandler.swift`
  - 处理 `userInfo["sessionId"]` 与 `userInfo["planDayIndex"]`
  - 触发 `navigationStack.append(.workout(sessionId:))`
  - 注册 `UNNotificationAction("start_training")`
  
- [ ] `NotificationPayloadBuilder.swift`（DongKeCore 新增）
  - 生成 `userInfo` 的序列化格式
  - 单测：`userInfo` 能被 Watch 端正确解码

**验收**：
- [ ] 真机验证：通知点开后进入训练页
- [ ] 通知正文包含「深蹲 4 组」等内容
- [ ] 点「已开始」能触发 `startFromNotification` 事件

---

### 📋 TICKET-W1.3：倒计时 UI + 状态机

**优先级**：P0 | **工时**：2 人日 | **阶段**：Phase 1  
**相关**：SPEC §4、`RestTimerStateMachine`

**描述**：
Watch 侧倒计时显示与状态管理，复用 iPhone 侧的 `RestTimerStateMachine`。

**交付物**：
- [x] `WatchRestView.swift`
  - 显示：「第 X 组，共 Y 组」（动作名 + 当前组/总组）
  - 显示：88pt 大字号倒计时（`monospacedDigit` + `minimumScaleFactor`）
  - 按钮：「+15 秒」「完成本组」
  - 无障碍：`spokenRemaining` 按 10 秒取整；VoiceOver 开启时每 10 秒 `AccessibilityNotification.Announcement`
- [x] `WatchWorkoutSession.swift`（Watch App 层）
  - `@Observable` + `restState: RestState`
  - 视图每 0.25s 调 `tick → RestTimerStateMachine.reduce`
  - `sync(with:)` 只在上下文 `updatedAt` 变化时重算，避免抹掉本地「+15 秒」
  - `scenePhase == .active` 时立刻 tick，按绝对时间重算
- [x] DongKeCore 补充
  - `RestTimerStateMachineTests.backgroundJumpFinishesInSingleTick` 已覆盖「跨 10 分钟后一次 tick 到 finished」

**验收**：
- [ ] 倒计时准确度 ±2s（真机锁屏 90s）
- [ ] 进后台不更新，回前台按绝对时间重算（逻辑已实现，待 runtime/真机走查）
- [ ] 点「+15 秒」能延长倒计时（逻辑已实现，待 runtime/真机走查）
- [ ] 点「完成本组」让倒计时回到 idle 态（逻辑已实现，待 runtime/真机走查）

**2026-11-24 落地**：Watch 端只做展示与本地计时；「完成本组」目前只结束休息，不落日志——
落日志与回传归 W2.3/W2.6。`DK_WATCH_DEMO_REST=1` 可在 DEBUG 下直接起 90 秒休息，供截图/走查。

---

### 📋 TICKET-W1.4：训练页基础布局

**优先级**：P0 | **工时**：1 人日 | **阶段**：Phase 1  
**相关**：SPEC §5

**描述**：
Watch 侧简化训练页，仅显示动作名、组号、目标值。

**交付物**：
- [x] `WatchWorkoutView.swift`
  - 显示当前动作名（从 `FlowStep` + `WatchContext.exercises` 解析）
  - 显示「第 X 组，共 Y 组」
  - 显示目标值（12 次 / 30 秒 / 每侧 10 次）
  - **不显示**骨架、要点、常见错误
  - 按钮：「完成本组」（Phase 1 禁用，标注「本组在 iPhone 上记录」；W2.6 接线）
- [x] 状态显示
  - 动作中：显示当天标题、动作、组号、目标
  - 休息中：切到 `WatchRestView`
- [x] 无障碍：整页合并为一个元素，标签「深蹲，第 1 组，共 3 组，目标 12 次」

**验收**：
- [ ] 能正确显示 3 个动作日的全部组合（需 runtime/真机）
- [ ] 文本不截断（已用 `lineLimit` + `minimumScaleFactor`，实际屏幕待 runtime 检查）
- [x] 无障碍标签正确（组合标签 + VoiceOver 播报）

**2026-11-24 落地**：Phase 1 的 Watch 只展示，不落日志；「完成本组」禁用并说明在 iPhone 记录，
W2.6 再打开并接 `PendingSetLog`。

---

### 📋 TICKET-W1.5：真机验证 checklist（Phase 1）

**优先级**：P0 | **工时**：0.5 人日 | **阶段**：Phase 1 end  
**相关**：SPEC §11、PRD §19.2

**描述**：
Walk through 五条人工验证场景，全部必须绿。

**测试环境**：
- 真机：Apple Watch Series 9 或更新
- iPhone 与 Watch 配对、App 已安装

**验收清单**：

1. ✅ **通知到点**
   - [ ] 修改系统时间到训练时刻（如 19:30）
   - [ ] 通知在 ±5 秒内弹出
   - [ ] 点通知进入 App

2. ✅ **倒计时准确**
   - [ ] 训练页显示「第 1 组，共 4 组，12 次」
   - [ ] 点「完成」进休息倒计时（60 秒）
   - [ ] 立刻锁屏，等待 60 秒
   - [ ] 解锁时界面应显示「已结束」（不是「剩余 N 秒」）

3. ✅ **加时功能**
   - [ ] 倒计时中点「+15 秒」
   - [ ] 秒数加上去
   - [ ] 继续倒计时

4. ✅ **完成按钮**
   - [ ] 倒计时结束后自动进下一组
   - [ ] 或手动点「完成」跳过倒计时
   - [ ] 组号正确递进

5. ✅ **辅助功能**
   - [ ] 开启 VoiceOver
   - [ ] 读出「第 1 组，共 4 组，目标 12 次」
   - [ ] 倒计时每 10 秒读一次秒数

**文档**：
- [ ] 生成 `docs/IWATCH-PHASE1-VERIFY.md` 包含这 5 个场景与截图指南

---

## Phase 2：续练 + 共享状态

---

### 📋 TICKET-W2.1：AppGroups 容器与文件锁设计

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 2 start  
**相关**：SPEC §2、§7、ADR-0004

**描述**：
设计 iPhone ↔ Watch 双向数据同步的容器结构与冲突解决规则。

**交付物**：
- [x] `AppGroupsStore.swift`（实际落在 `DongKeCore/Data`，容器 URL 可注入）
  - 路径：`group.com.dongke.shared/workouts/`
  - 创建方法：`saveCheckpoint`、`readPendingLogs()`、`appendPendingLog(_:sourceDevice:)`
  - 文件锁：JSON Lines 追加模式（每行一条记录），`O_APPEND` + `flock`
  - 修正：App Group 只在本机共享，跨设备传输见 IWATCH-APPGROUPS.md §0
- [x] 冲突处理规则单测
  - 场景：iPhone 与 Watch 同时记组 3
  - 验证：去重使用 `(sessionId, setIndex, sourceDevice)` 三元组
  - 验证：重复日志在 `SessionLedger.merge` 时合并，不在存储层
- [x] 文档：`docs/specs/IWATCH-APPGROUPS.md`
  - JSON Lines 格式说明
  - 写入顺序与读取流程

**验收**：
- [x] 单测通过（16 条，覆盖并发追加与坏行容错；20+ 条随 W2.3 队列/重试补齐）
- [x] 离线场景：先记再读，无数据丢失（临时目录注入验证；真机待 entitlement 注册）

---

### 📋 TICKET-W2.2：Checkpoint 序列化与恢复

**优先级**：P0 | **工时**：1 人日 | **阶段**：Phase 2  
**相关**：SPEC §2、§6

**描述**：
定义 `WorkoutCheckpoint` 的序列化格式，实现 Watch 侧的「断点续练」。

**交付物**：
- [x] `WorkoutCheckpoint: Codable`（并入 `DongKeCore/Workout/WorkoutCheckpoint.swift`，不新建同名类型）
  ```swift
  struct WorkoutCheckpoint {
      let sessionId: UUID
      let steps: [FlowStep]?         // 执行序列（原 ticket 的 script）
      let stepIndex: Int
      let logs: [SetLog]
      let revision: Int              // 计划版本号
      let status: WorkoutStatus      // 新增；老断点缺省 .inProgress
      let startedAt: Date
      let updatedAt: Date            // 原 ticket 的 lastUpdatedAt
  }
  ```

- [x] `CheckpointStore.swift`（`DongKeCore/Services`，实例 + 注入）
  - 写入：`save(_:)` → JSON 文件（App Group）
  - 读取：`load(sessionId:)` → `WorkoutCheckpoint?`
  - 清理：`remove(sessionId:)` 训练结束时调用
  - iPhone 侧：`WorkoutSession.saveCheckpoint` 双写 UserDefaults + App Group

- [ ] Watch 侧使用（阻塞：Watch target 未创建）
  - App 冷启动时：尝试 `CheckpointStore.load()`
  - 若成功：显示「继续上一组」或「从头开始」
  - 若失败或无：进入新建会话流程

**验收**：
- [x] 单测：序列化往返完整性、老格式兜底、revision 比对
- [ ] 真机：App 被杀后重启，能恢复到断点（阻塞：Watch target）

---

### 📋 TICKET-W2.3：Watch 日志同步与重试机制

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 2  
**相关**：SPEC §5、§7

**描述**：
Watch 侧记完日志后，通过 AppGroups 追加到 iPhone，失败时本地队列化。

**交付物**：
- [x] `PendingLogSync.swift`（实际落在 DongKeCore/Watch，Core 可单测）
  - `PendingLogQueue` actor：入队、待发数、24 小时告警判定
  - `LogRetryScheduler`：5s → 10s → 30s（之后固定 30s），成功清零
  - `PendingLogSending` 协议：传输层可替换
- [x] `WatchLogSender.swift`（Watch App）
  - `WCSession.default.transferUserInfo` 交棒；未激活时抛错，队列保留
  - 交棒成功即从 outbox 删除；WCSession 自己负责断线重传
- [x] iPhone `WatchSyncService.didReceiveUserInfo`：解码 `PendingSetLog` → 写入 iPhone 本机 outbox
- [x] 触发时机：入队立即 flush；Watch 进前台 `refreshPending + flushPending`
- [x] 失败处理：按退避重试 4 次（5/10/30/30 秒），UI 显示「待同步（N 组）」

- [ ] 后台定时任务（`BGProcessingTask` / watchOS 后台刷新）：未实现
- [ ] W2.4：iPhone 把 outbox 合并进 SwiftData / SessionLedger（本轮只落 outbox，不丢日志）

**单测（`PendingLogSyncTests`，15 条）**：
- 调度器：初始可试、5/10/30 序列、边界、成功清零
- 队列：入队、空队列、全部成功、中途失败只删已成功、退避期跳过、到点重试成功、
  连续失败序列、成功后重新计时、退避期新增不丢、24h 告警、空队列不告警

**验收**：
- [x] 单测通过（15 条）
- [ ] 真机飞行模式测试：完成 3 组 → 关飞行模式 → 1 秒内同步到 iPhone（无 runtime/真机）

**已知限制**：
- `transferUserInfo` 的 `didFinishUserInfoTransfer` 失败回调没有把条目重新入队；WCSession 自己的传输队列通常能重试，但极端情况下需要补一条回滚路径。
- 日志到 iPhone 后只进 App Group outbox，尚未进 SwiftData（W2.4）。

---

### 📋 TICKET-W2.4：iPhone 侧日志合并与去重

**优先级**：P0 | **工时**：1 人日 | **阶段**：Phase 2  
**相关**：ADR-0006、SPEC §7

**描述**：
iPhone 侧读 Watch 的待同步日志，合并进 `SessionLedger`，处理重复。

**交付物**：
- [x] `SessionLedger.merge(prescribedSets:local:remote:)`（DongKeCore/Workout）
  - 存储层按 `(sessionId, setIndex, sourceDevice)` 去重；账本层按 `SetLogKey` 折叠跨设备同组
  - iPhone 本地日志优先
- [x] 写入门禁
  - `WatchLogInbox`：读 outbox → 活跃会话 `ingestRemoteLog`（按 `SetLogKey` 去重）→
    无活跃会话 `SetLogStore.addIfAbsent` → **落库成功才删条目**
  - `SetLogStore.add` 返回 Bool；`addIfAbsent` 按账本键判重
- [x] 单测
  - 跨设备同组只计一次（`SessionLedgerMergeTests`）
  - `SetLogKey` 忽略 id/设备、区分 origin（2 条）

**验收**：
- [x] 单测通过（953 条全绿）
- [x] 模拟器端到端：outbox 一条日志 → 重启 → `ZSETLOGENTITY` +1、pending 清零；
      同账本键不同 id 再写一次 → 仍 1 条
- [ ] 完成率数字两端一致（需配对 Watch 实测）

**2026-11-24 落地补充**：
- 发现并修掉 **SwiftData 默认 `groupContainer: .automatic` 会把整库搬进 App Group** 的问题
  （`ModelConfiguration(groupContainer: .none)`），见 HANDOFF §6.33。
- 无活跃会话时直接落 `SetLogStore`，不会更新 `SessionEntity`；历史页的「训练天/会话列表」
  在「iPhone 没起训、只有 Watch 日志」这种边缘场景可能少一次。主链路不受影响。

---

### 📋 TICKET-W2.5：计划更新冲突检测

**优先级**：P0 | **工时**：0.5 人日 | **阶段**：Phase 2  
**相关**：SPEC §6、ADR-0004

**描述**：
当 iPhone 侧计划 revision 变更时，检测 Watch 是否还在旧版本训练。

**交付物**：
- [x] `CheckpointValidator.swift`（DongKeCore/Workout）
  - 顺序：`notInProgress` > `planChanged` > `expired` > `resumable`
  - iPhone 的断点续练也改用同一个校验器；计划改版不再弹出旧计划续练
- [x] iPhone 下发实时 `planRevision`
  - `WatchSyncService.setPlanRevision`，与 context 同一个 applicationContext
  - AppShell 在启动与 `activePlan.revision` 变化时调用
- [x] Watch 侧处理
  - `WatchWorkoutView` 按校验结果切换：可续 / 已结束 / 计划已更新 / 已过期
  - 计划改版显示「请回到 iPhone 完成或重新开始本次训练」
  - `completeSet` 在非 `.resumable` 时直接拒绝，不产生日志

**验收**：
- [x] 单测通过（9 条：可续、改版、已完成、已放弃、跨天、越界、空步骤、两条优先级）
- [x] 模拟器：`DK_SEED_CHECKPOINT=1` 且 revision 一致时，今日页正常出现「上次训练没做完」
- [ ] 真机：iPhone 推送新计划 → Watch 侧收到告知（需配对设备）

---

### 📋 TICKET-W2.6：Watch 侧完成组 UI 与逻辑

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 2  
**相关**：SPEC §5

**描述**：
Watch 侧点「完成本组」时，记录 SetLog、更新 UI、尝试同步。

**交付物**：
- [x] `WatchWorkoutView` 更新
  - 按钮「完成本组」可点
  - 点击后：
    1. 本地创建 `SetLog`（`catalogId` 来自 `WatchExerciseInfo`）
    2. UI 显示「已记录（同步中）」
    3. `localStepIndex` 推进；本组 `restAfterSec > 0` 时直接进休息倒计时
    4. 入队 + 立即 flush
- [x] 同步失败的 UI
  - 「待同步（N 组）」；超过 24 小时提示「请打开 iPhone」
  - 本地通知未加（显示层文案先到位）

**验收**：
- [ ] 真机：点完成 → 秒内进休息倒计时（需配对设备）
- [ ] 真机飞行模式：记完 3 组 → 显示「待同步（3 组）」（需配对设备）

**2026-11-24 落地**：本地推进是乐观的，iPhone 收到的下一份 `WatchContext` 仍是权威；
`sync` 用 `max(localStepIndex, checkpoint.stepIndex)` 防止回退。休息若被 iPhone 的旧上下文
短暂取消，会由下一份带 `restEndsAt` 的上下文恢复。

---

### 📋 TICKET-W2.7：真机验证 checklist（Phase 2）

**优先级**：P0 | **工时**：0.5 人日 | **阶段**：Phase 2 end  
**相关**：SPEC §11

**描述**：
Walk through 十条人工验证场景（Phase 1 的 5 条 + Phase 2 新增 5 条）。

**新增 5 条**：

6. ✅ **离线记录 + 同步**
   - [ ] 打开飞行模式
   - [ ] Watch 完成 3 组
   - [ ] 关闭飞行模式
   - [ ] 等待 1 秒，检查 iPhone 新日志出现
   - [ ] 完成率数字一致

7. ✅ **断点续练**
   - [ ] 完成 2 组后主动杀掉 Watch App
   - [ ] 重启 Watch App
   - [ ] 显示「继续上一组」
   - [ ] 点继续 → 进组 3
   - [ ] 完成率分母不变

8. ✅ **冲突处理**
   - [ ] iPhone 与 Watch 同时点「完成」（靠手速模拟）
   - [ ] 任意一方同步成功后，另一方应显示「已同步」
   - [ ] 最终完成率正确（不重复计）

9. ✅ **计划更新**
   - [ ] 训练中，iPhone 推送新版本计划（`revision += 1`）
   - [ ] Watch 收到警告「计划已更新」
   - [ ] 能返回 iPhone 完成训练

10. ✅ **网络恢复**
    - [ ] 飞行模式完成 10 组
    - [ ] 24 小时不关飞行
    - [ ] 关飞行后，所有日志无丢失
    - [ ] 检查 Watch 本地队列已清空

**文档**：
- [ ] 更新 `docs/IWATCH-PHASE2-VERIFY.md`

---

## Phase 3：骨架显示（Post-MVP）

---

### 📋 TICKET-W3.0：前置决策——中文 TTS 引擎选型

**优先级**：P2 | **工时**：—（决策项，不编码）  
**相关**：ADR-0007

**描述**：
评估是否在 Watch 侧加入语音播报，选择合适的 TTS 引擎。

**决策点**（先不实现，1.1 或更后决策）：
1. 是否需要语音播报（做过用户调研否）
2. 音质 / 延迟 / 包体积是否可接受
3. 商用许可是否干净

**无决议前**：
- 播报仍用系统 TTS（compact 音色）
- Watch 侧不做任何中文 TTS 相关代码

---

### 📋 TICKET-W3.1：骨架数据同步与体积优化

**优先级**：P2 | **工时**：2 人日  
**阶段**：Phase 3  
**相关**：SPEC §2、§12

**描述**：
（前置：Phase 2 验证日留存 ≥ 50% ）

从 `GeneratedFigureData.swift`（3MB）提取子集，压缩到 1–2MB，可在 Watch 离线显示。

**交付物**：
- [ ] `FigureOptimizer.swift`（工具脚本）
  - 输入：完整 `GeneratedFigureData`
  - 输出：只含首帧、体积 ≤2MB 的 Watch 专用集合
  - 映射：`[catalogId: StaticPose]`

- [ ] Watch 侧集成
  - 包大小核实
  - 加载性能（冷启动延迟 <100ms）

**验收**：
- [ ] Watch App 总包体 ≤50MB（Apple 要求）
- [ ] 骨架加载时间 <100ms
- [ ] 真机显示无歪曲

---

## 总体进度表

| Phase | 周期 | Tickets | 工时 | 验收点 |
|---|---|---|---|---|
| 1 | W1–W5 | W1.1–W1.5 | 6 人日 | 5 条人工验证 ✓ |
| 2 | W6–W10 | W2.1–W2.7 | 7 人日 | 10 条人工验证 ✓ |
| 3 | W11+ | W3.0–W3.1 | 2 人日 | 决策 + 可选 |

**总计**（Phase 1–2）：**13 人日** ≈ **3–4 周**（1.5–2 人编码）

---

## 拒收标准（三条都要过）

- [ ] Phase 1 全部 Tickets 完成 + 5 条人工验证全绿
- [ ] Phase 2 全部 Tickets 完成 + 10 条人工验证全绿
- [ ] 无 Core 侧代码改动被破坏（单测必须 100% 通过）
- [ ] 架构 §4 的四大约束全部满足（见第一步自审）

