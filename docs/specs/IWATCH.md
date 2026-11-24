# Apple Watch 伴生 App 规格

版本：0.1（Phase 1 MVP 范围）  
状态：设计评审中  
相关 ADR：0001, 0004  
相关决策：D-18（本期确认"Watch 不做完整执行流"）

---

## 1. 范围与阶段

### Phase 1：通知 + 倒计时（MVP 验证）

**核心价值**：
- 健身房场景下，用户不必掏 iPhone 看倒计时
- 验证「Watch 用户是否真的会用」

**功能边界**：
- ✓ 通知显示今天训练摘要
- ✓ 进 App 看到当前组号与目标值（无骨架图）
- ✓ 倒计时环形进度（继承自 iPhone 侧设计）
- ✗ 不做完整执行页（骨架、要点、常见错误）
- ✗ 不做离线计划下载到 Watch
- ✗ 不做降阶选项（直接回 iPhone 完成）

**验收标准**：
- 通知到点 ±5 秒弹出
- 倒计时准确度 ±2 秒（真机锁屏 90 秒验证）
- 点「已开始」让 iPhone 侧记录进行中会话
- 人工走查：通知 → 点进 → 倒计时走 → 结束

---

### Phase 2：续练 + 共享状态（usefulness 验证）

**新增价值**：
- 健身房场景下完全闭环（不需要 iPhone）
- 记录立刻同步回 iPhone（无分裂感）

**新增功能**：
- ✓ Watch 侧保存 `WorkoutCheckpoint`（断点状态、当前组号、已完成日志）
- ✓ Watch App 显示「第 2 组，目标 12 次」可点「完成」
- ✓ 会话日志通过 AppGroups 共享容器**双向同步**
- ✓ 离线记录本地队列化，回网后重试
- ✓ 点「+30 秒」加时（Watch 物理按钮）
- ✗ 仍不做降阶选项
- ✗ 仍不做离线计划下载

**验收标准**：
- 断点续练成功率 ≥ 95%
- 离线完成日志 ≤ 1 秒同步回 iPhone
- 完成率数字两端一致（误差 0）
- 网络断 10 分钟后恢复，日志无丢失

---

### Phase 3：骨架显示（Post-MVP）

**前置条件**：
- Phase 2 验证日留存 ≥ 50%
- Watch 本体反馈无「太慢」投诉
- Apple Watch 市占依然 ≥ 15%

**新增**：
- 简化版骨架（3 帧中取首帧）
- 体积目标：±2MB（不超过总包 15%）

---

## 2. 数据模型

### 新增类型

```swift
// Phase 1
struct WatchContext {
    let currentDayIndex: Int
    let currentSetIndex: Int
    let currentTarget: SetTarget          // 目标值与类型
    let totalSets: Int
    let restEndAt: Date?
}

// Phase 2
struct WorkoutCheckpoint: Codable {
    let sessionId: UUID
    let script: [FlowStep]                 // 完整执行序列
    let stepIndex: Int                     // 当前在第几步
    let logs: [SetLog]                     // 已完成日志
    let status: WorkoutStatus              // 进行中/完成/放弃
    let startedAt: Date
    let lastUpdatedAt: Date
}
```

### 共享容器路径（Phase 2）

```
AppGroup 路径：group.com.dongke.shared/workouts/
  ├── checkpoint-{sessionId}.json         // 当前会话快照（iPhone 写）
  ├── pending-logs.jsonl                  // Watch 待同步日志队列
  └── sync-status.json                    // {sessionId, lastSyncAt, pendingCount}
```

**写入规则**：
- **iPhone 侧**：
  - `checkpoint` 每 2 秒写一次（训练中）
  - 计划改版时覆盖整个 `checkpoint`（新 `revision`）
  - 读 `pending-logs.jsonl` 并按 `(sessionId, setIndex)` 去重
- **Watch 侧**：
  - 新日志**追加**到 `pending-logs.jsonl`（永不覆盖）
  - 每条 1 行 JSON（`SetLog + timestamp`）
  - 每 10 秒或进后台时尝试同步

---

## 3. 通知流（Phase 1–2 通用）

### 触发时机

```
WeeklyScheduleGenerator.makeSpecs(plan:settings:)
  → 为每个训练日生成一条 ReminderSpec
  → NotificationService.reschedule()
  → add(UNNotificationRequest(categoryIdentifier: "workout"))
```

### 通知内容

```
title:    "今天练下肢"
body:     "深蹲 4 组、箭步蹲 3 组，预计 28 分钟"
userInfo: {
  "sessionId": "...",
  "planDayIndex": 2,
  "leadMinutes": 5
}
```

### 通知动作（Watch 自动处理）

| 动作 | 处理 | 结果 |
|---|---|---|
| 点通知 | Deep link 到 Watch App | 打开 App 并加载该 session |
| 「已开始」 | 发送通知回到 iPhone | iPhone 侧记录 `startedFrom: .watch` |

---

## 4. 倒计时设计（Phase 1）

### 状态机（复用 Core 的 `RestTimerStateMachine`）

```swift
enum RestState {
    case idle
    case running(endAt: Date, totalSeconds: Int)
    case finished(totalSeconds: Int)
}
```

**关键约束**：
- 进后台时，倒计时**停止**（iPhone 侧靠本地通知兜底）
- 回前台时，按绝对时间 `endAt` 重算（不追赶）
- 倒计时准确度：±2 秒（硬件限制）

### Watch 侧显示

```
┌─────────────────┐
│   第 2 组        │  ← setIndex / totalSets
│   共 4 组        │
├─────────────────┤
│      88          │  ← 秒数（88pt 单独字号）
│    剩余秒        │
├─────────────────┤
│  [+15 秒]        │  ← 加时按钮（56pt 点击区）
│  [完成本组]      │
└─────────────────┘
```

**无障碍**：
- `accessibilityLabel("第 2 组，共 4 组，目标 12 次")`
- 倒计时每 10 秒更新一次播报（VoiceOver 读数）

---

## 5. 执行流（Phase 2）

### Watch 侧简化执行页

```swift
struct WatchWorkoutView {
    @State var checkpoint: WorkoutCheckpoint
    @State var step: FlowStep?           // 当前步骤
    
    // 只显示以下内容
    // 当前动作名 → 组号 → 目标值
    // 若是休息：倒计时 + 加时按钮
    // 若是动作：仅文本「第 2 组，目标 12 次」+ 完成按钮
}
```

**不显示**：
- 骨架图（屏幕太小）
- 要点与常见错误
- 降阶选项（返回 iPhone 操作）

### 点击「完成本组」时

```
Watch 侧 → 记录 SetLog（本地）
       → 追加到 pending-logs.jsonl
       → 显示「已记录（同步中）」
       → 后台尝试同步到 iPhone
       
iPhone 侧 → 读 pending-logs.jsonl
        → 按 (sessionId, setIndex) 去重
        → 更新 SessionLedger
        → 下一组推进
```

**同步失败的处理**：
- UI 显示「待同步（N 组）」
- 轮询重试（指数退避：5s → 10s → 30s）
- 24 小时后若未同步，给 Watch 侧通知「同步失败，请打开 iPhone」

---

## 6. 断点续练（Phase 2）

### 情景 A：用户 50 分钟前启动了训练，然后 Watch 没电了/被关掉

```
① Watch 侧本地存有 Checkpoint + pending-logs.jsonl（最后 30 分钟）
② 重启 Watch 进 App → 触发 `loadCheckpoint(sessionId:)`
③ 显示「继续上一组」或「从头开始」
④ 选「继续」→ 从组 7 开始（不改分母，不清历史）
```

### 情景 B：iPhone 也在同一时间做了改动（收到推送计划更新）

```
① iPhone 侧 `newPlan.revision += 1`
② Watch 还在老版本的 Checkpoint 里
③ 下一组进来时检查 `checkpoint.revision == currentPlan.revision`
④ 若不符 → 给 Watch 通知「计划已更新，请返回 iPhone 完成本次训练」
```

---

## 7. 写冲突处理（Phase 2）

### 场景：iPhone 记完组 3，Watch 也在记组 3

```
iPhone:   pending-logs.jsonl 已包含 (sessionId, 3, iphone-ts)
Watch:    要追加 (sessionId, 3, watch-ts)

处理方案：
1. Watch 追加时在 JSON 末尾加 `"sourceDevice": "watch"`
2. iPhone 读时用 `(sessionId, setIndex, sourceDevice)` 三元组去重
3. 重复来自**同一设备**才算重复；不同设备的两条各记一条
4. SetLog.origin 仍只有一个值，重复日志在 SessionLedger.merge 时才合并
```

### 冲突判定

```swift
// SetLogStore.merge(local: [SetLog], remote: [SetLog])
let key = { ($0.sessionId, $0.setIndex, $0.sourceDevice) }
let merged = Dictionary(grouping: local + remote, by: key)
                .mapValues { $0.first }     // 每个三元组取第一条
                .values
```

---

## 8. 配置与权限

### WatchKit Entitlements

```
com.apple.developer.homekit
com.apple.developer.usernotifications.time-sensitive
com.apple.security.application-groups    ← AppGroups
```

### Info.plist

```xml
<key>WKAppBundleIdentifier</key>
<string>com.dongke.watch</string>
```

### 权限请求

- **通知**：从 iPhone 侧 `UNUserNotificationCenter.requestAuthorization()`
  - Watch 侧由系统自动继承（不需要重复请求）
- **Motion & Fitness**：本期**不请求**（不读步数）
- **HealthKit**：本期**不请求**（不读心率）

---

## 9. 离线支持

### Phase 1（已全离线）

```
功能               网络依赖
─────────────────────────
通知触发            ✗（本地通知）
倒计时              ✗（绝对时间 + 系统计时）
```

### Phase 2（大部分离线）

```
功能               网络依赖     降级方案
─────────────────────────────────────────
读 Checkpoint      ✗ 完全离线   本地 checkpoint.json
记日志             ✗ 完全离线   本地 pending-logs.jsonl
同步日志到 iPhone  ✓ 需要网络   失败时本地队列化，回网重试
```

**离线时长**：≤30 天（Watch 存储压力），超期给用户提示「请连接 iPhone」

---

## 10. 性能指标

| 指标 | 目标 | 验证方式 |
|---|---|---|
| 冷启动到首屏 | <2s | XCTest + Instruments |
| 通知到点延迟 | ±5s | 真机手动验证（模拟器不准） |
| 倒计时准确度 | ±2s | 锁屏 60 秒，拍照对比 |
| 完成日志同步 | <1s（有网） | XCTest + 模拟网络 |
| 离线日志保留 | ≤30 天 | 配置检查 |

---

## 11. 测试策略

### 单元测试

```
DongKeCoreTests/
  └── WatchIntegration/
      ├── WorkoutCheckpointTests.swift
      ├── AppGroupsSyncTests.swift
      └── RestTimerStateMachineTests.swift    ← 复用 iPhone 侧测试
```

### 集成测试

```
DongKeWatchTests/（Watch target 中）
  ├── WatchWorkoutViewTests.swift
  ├── NotificationHandlingTests.swift
  └── OfflineSyncTests.swift
```

### 真机验证（人工走查）

```
1️⃣ 通知到点
   - 修改系统时间到训练时刻 ±2 分钟
   - 验证通知在 ±5 秒内弹出

2️⃣ 倒计时准确度
   - 设置 60 秒休息
   - 立刻锁屏，等待 60 秒
   - 解锁时界面应显示「已结束」（不是「剩余 N 秒」）

3️⃣ 续练
   - 完成 2 组后主动杀掉 App
   - 重启 Watch App
   - 验证「继续上一组」能恢复到组 3

4️⃣ 离线同步
   - 打开飞行模式，Watch 完成 3 组
   - 关闭飞行模式，等待 1 秒
   - iPhone 侧验证新日志出现

5️⃣ 冲突处理
   - iPhone / Watch 同时点「完成」
   - 任意一方同步成功后，另一方应显示「已同步」而不是「重复记录」
```

---

## 12. 已知限制与 P1 递延

| 限制 | 原因 | P1 计划 |
|---|---|---|
| 不显示骨架图 | Watch 屏幕 1.3"，取景混乱 | Phase 3 再加；仍仅首帧，不播放 |
| 不显示动作要点 | 同上 | 同上 |
| 不支持降阶选项 | 屏幕太小无法展示 ActionSheet | 同上 |
| 不支持语音播报 | Watch 内置 TTS 质量差，噪声高 | 研究后决策；暂不做 |
| 不支持心率数据 | 无 HealthKit 权限 | 确认用户需求后再加 |

---

## 13. 交付清单

### Phase 1（2–3 周）

- [ ] `DongKeWatch` target 新建
- [ ] 通知处理 + Deep link
- [ ] 倒计时环形进度显示
- [ ] 真机验证清单 5 条全绿
- [ ] `WatchContext` 数据流打通

### Phase 2（1–2 周）

- [ ] AppGroups 容器设计 + 文件锁
- [ ] `WorkoutCheckpoint` 序列化
- [ ] 断点续练 UI + 逻辑
- [ ] 日志同步与冲突处理
- [ ] 离线队列化与重试
- [ ] 真机验证清单 5 条 + 新增 5 条全绿

### Phase 3（Post-MVP）

- [ ] 决策：中文 TTS 引擎选型（MeloTTS / Vits / 系统 TTS）
- [ ] 骨架同步与体积优化
- [ ] 语音播报集成

---

## 14. 风险清单

| # | 风险 | 后果 | 对策 |
|---|---|---|---|
| 1 | AppGroups 文件锁失败 | 重复日志 / 数据损坏 | 预选 JSON Lines 格式，用 setIndex 去重 |
| 2 | Watch 进后台计时走偏 | 倒数时间不准 | 绝对时间 + 本地通知，不依赖 App 进程 |
| 3 | 离线日志堆积 > Watch 存储 | App 崩溃 | 30 天滚动清理，超期给通知 |
| 4 | 计划更新但 Watch 未同步 | 执行旧计划 | Checkpoint 加 `revision` 检查 + 冲突告知 |
| 5 | iPhone 与 Watch 同时结束训练 | 两条 `WorkoutSession` | 防重：用 `sessionId` 唯一约束 |

