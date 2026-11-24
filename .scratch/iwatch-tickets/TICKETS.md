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

### 📋 TICKET-W1.2：通知处理与深链

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 1  
**相关**：SPEC §3、SPEC §6

**描述**：
实现从 iPhone 侧到 Watch 侧的通知流，包括消息解析、Deep link 处理。

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
- [ ] `WatchRestView.swift`
  - 显示：「第 X 组，共 Y 组」
  - 显示：88pt 大字号倒计时秒数
  - 按钮：「+15 秒」「完成本组」
  - 无障碍：每 10 秒更新 VoiceOver 播报

- [ ] `WatchWorkoutSession.swift`（Watch App 层）
  - `@State var restState: RestState`
  - 每 0.25s 调一次 `RestTimerStateMachine.reduce(...)`
  - 处理 `scenePhase` 变化

- [ ] DongKeCore 补充
  - 验证 `RestTimerStateMachine` 在 Watch 侧也能用
  - 增加一条单测：「时间跨越 10 分钟（进后台）后，tick 一次直接到 finished」

**验收**：
- [ ] 倒计时准确度 ±2s（真机锁屏 90s）
- [ ] 进后台不更新，回前台按绝对时间重算
- [ ] 点「+15 秒」能延长倒计时
- [ ] 点「完成本组」让倒计时回到 idle 态

---

### 📋 TICKET-W1.4：训练页基础布局

**优先级**：P0 | **工时**：1 人日 | **阶段**：Phase 1  
**相关**：SPEC §5

**描述**：
Watch 侧简化训练页，仅显示动作名、组号、目标值。

**交付物**：
- [ ] `WatchWorkoutView.swift`
  - 显示当前动作名（从 `FlowStep` 解析）
  - 显示「第 X 组，共 Y 组」
  - 显示目标值（12 次 / 30 秒 / 每侧 10 次）
  - **不显示**骨架、要点、常见错误
  - 按钮：「完成这组」

- [ ] 状态显示
  - 动作中：显示文本说明
  - 休息中：显示倒计时（复用 `WatchRestView`）

**验收**：
- [ ] 能正确显示 3 个动作日的全部组合
- [ ] 文本不截断（Watch 屏幕尺寸检查）
- [ ] 无障碍标签正确

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
- [ ] `WatchLogQueue.swift`（Watch App）
  - 队列数据结构：`[SetLog]` with `sourceDevice: "watch"`
  - 提交方法：`append(log:)` → 本地存储 + 尝试同步
  - 重试逻辑：指数退避（5s → 10s → 30s）

- [ ] `PendingLogSync.swift`（DongKe/Services）
  - 触发时机：
    1. 写入即刻尝试（若网络可用）
    2. App 进前台时重试所有未同步日志
    3. 后台定时任务（`BGProcessingTask`，30 秒间隔）
  - 失败处理：记录失败原因，轮询重试

- [ ] 单测
  - 场景 A：网络可用，日志即刻同步
  - 场景 B：网络断开，本地队列化，恢复后自动重试
  - 场景 C：同步超时 24 小时，给用户通知

**验收**：
- [ ] 单测通过（15+ 用例）
- [ ] 真机飞行模式测试：完成 3 组 → 关飞行模式 → 1 秒内同步到 iPhone

---

### 📋 TICKET-W2.4：iPhone 侧日志合并与去重

**优先级**：P0 | **工时**：1 人日 | **阶段**：Phase 2  
**相关**：ADR-0006、SPEC §7

**描述**：
iPhone 侧读 Watch 的待同步日志，合并进 `SessionLedger`，处理重复。

**交付物**：
- [ ] `SessionLedger.merge(local:remote:)`（DongKeCore/Workout）
  - 输入：`[SetLog]`（本地）+ `[SetLog]`（Watch）
  - 去重主键：`(sessionId, setIndex, sourceDevice)`
  - 输出：合并后的 `SessionLedger`（计数一致，无重复）

- [ ] 写入门禁
  - 一旦 `SetLogEntity` 落库，即刻清掉 AppGroups 里对应的日志
  - 防止重复计两遍

- [ ] 单测
  - 场景：iPhone 记了组 1–2，Watch 记了组 2–4，来源不同
  - 验证：最终 `SessionLedger` 有 4 条，组 2 仅计一次

**验收**：
- [ ] 单测通过
- [ ] 完成率数字两端一致（误差为 0）

---

### 📋 TICKET-W2.5：计划更新冲突检测

**优先级**：P0 | **工时**：0.5 人日 | **阶段**：Phase 2  
**相关**：SPEC §6、ADR-0004

**描述**：
当 iPhone 侧计划 revision 变更时，检测 Watch 是否还在旧版本训练。

**交付物**：
- [ ] `CheckpointValidator.swift`
  - 检查：`checkpoint.revision == currentPlan.revision`
  - 若不符：给 Watch 通知「计划已更新，请返回 iPhone」
  - 阻止：Watch 继续用旧版本执行

- [ ] Watch 侧处理
  - UI：显示警告与「回到 iPhone」按钮
  - 逻辑：不允许继续记新日志

**验收**：
- [ ] 单测通过
- [ ] 真机：iPhone 推送新计划 → Watch 侧收到告知

---

### 📋 TICKET-W2.6：Watch 侧完成组 UI 与逻辑

**优先级**：P0 | **工时**：1.5 人日 | **阶段**：Phase 2  
**相关**：SPEC §5

**描述**：
Watch 侧点「完成本组」时，记录 SetLog、更新 UI、尝试同步。

**交付物**：
- [ ] `WatchWorkoutView` 更新
  - 按钮「完成本组」可点
  - 点击后：
    1. 本地创建 `SetLog`（带 `sourceDevice: "watch"`）
    2. UI 显示「已记录（同步中）」
    3. 推进到下一步（下一组或休息）
    4. 后台尝试同步

- [ ] 同步失败的 UI
  - 显示「待同步（N 组）」
  - 给用户通知「检查网络连接」

**验收**：
- [ ] 真机：点完成 → 秒内进休息倒计时
- [ ] 真机飞行模式：记完 3 组 → 显示「待同步（3 组）」

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

