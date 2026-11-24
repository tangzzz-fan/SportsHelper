# 会话的发起与放弃：一个裁决器，一条意图通道

状态：设计稿（未实现）
上位依据：`docs/specs/IWATCH.md`、`.scratch/iwatch-tickets/TICKETS.md`（W1.2 遗留的 `startedFrom`、W2.2 遗留的「从头开始」）

---

## 0. 结论先说

`startedFrom: .watch` 和「从头开始」不是两件事，是同一件事的两面：**谁有权决定「当前是哪一次会话」**。

现在有三个地方能开始训练，各自 `UUID()` 新建，没有任何地方校：「已经有一次在进行了」。所以先有一个裁决器（Core 纯函数），再有一条 Watch → iPhone 的意图通道。**意图通道是裁决器的第二个调用方，不是新机制。**

顺带，本 spec 修一个与 Watch 无关、但同源的真实缺陷（§1）。

---

## 1. 当前就有的 bug：点休息通知，进度归零

这条不在原票里，是查证过程中发现的，优先级高于本 spec 其余部分。

### 复现

1. 开始训练，做完 5 组，进入组间休息 90 秒，锁屏
2. 休息结束通知响起（`dk.rest.<sessionId>`），点它
3. 回到 App，**看到第 1 组**，之前 5 组的进度从界面上消失

### 实测（2026-11-25，iPhone 18 Pro 模拟器）

用 `DK_SEED_CHECKPOINT=1` 造一个第 4/13 步的断点，对照组截图显示「上次训练没做完 · 停在第 4/13 步」。杀掉进程，用同一个断点、加上 `DK_OPEN_REMINDER=0`（走 `openWorkout` 同一个入口）冷启动：

| 观测点 | 预期（若只是视图重置） | 实测 |
|---|---|---|
| 训练页进度 | 第 4 步 | **第 1 组 / 共 4 组** |
| `dk.workout.checkpoint` 的 `stepIndex` | 仍是 3 | **0** |
| `sessionId` | 与原断点一致 | **已换新** |

所以不是「视图重置」，是**断点被覆盖、旧进度永久丢失**。用户拿到的是「今天这次训练从第 1 组重新开始」，没有任何提示。

### 为什么

`NotificationService.scheduleRestEndNow` 写的载荷是 `ReminderPayload.userInfo(dayIndex:)`（`DongKe/Services/NotificationService.swift:139`），跟每日提醒同一个键。`NotificationRouter` 只认 `dayIndex`，不看 `identifier` 前缀，于是把它当成「该练了」处理：

```swift
// DongKe/Services/NotificationRouter.swift:37
if let dayIndex = ReminderPayload.dayIndex(from: userInfo) {
    link = .dayIndex(dayIndex)
}
```

`AppShell.openWorkout` 拿到 dayIndex 后**直接新建会话**，不看 `resumeCandidate`：

```swift
// DongKe/Features/Shell/AppShell.swift:234
private func openWorkout(_ link: WorkoutDeepLink) {
    ...
    start(dayIndex: dayIndex, on: occurrence?.date, in: plan)   // 新 UUID，stepIndex = 0
}
```

`fullScreenCover(item: $session)` 的 item 换成了新对象，视图重建。而这行会立刻把单槽断点写成新会话的：

```swift
// DongKe/Features/Workout/WorkoutView.swift:259
.onAppear { session.saveCheckpoint() }
```

`WorkoutCheckpointStore` 是单槽（`dk.workout.checkpoint`，`DongKe/Data/WorkoutCheckpointStore.swift:6`），`saveCheckpoint` 用新会话的 `id` / `stepIndex = 0` 覆盖同一个 key。**旧断点没有留下任何痕迹**——上面实测里 `stepIndex` 从 3 变成 0 就是这么来的。

这行的本意是「进训练页就落一次断点，防杀进程」。它没错，错在**它假设进训练页的一定是同一个会话**。这个假设只在所有入口都过裁决器时才成立。

### 影响面

不止休息通知。任何带 `dayIndex` 的通知被点都走这条路：每日提醒、休息结束、将来的其他提醒。用户的感受是「练到一半点了个通知，白练了」。

### 修法

`openWorkout` 改走裁决器（§3）。断点可续且 `dayIndex` 对得上时 `.resume`，对不上时才 `.create`。

`WorkoutView.onAppear` 那行也要改语义：**广播照旧，落盘要看有没有进度**。

```swift
// 广播：Watch 要立刻知道「iPhone 上开练了」。否则用户点「已开始」建完会话，
// 手表那边还是空态（§4.5 要靠这条）。
// 落盘：一组都没做时不写，否则单槽断点会被一个空会话占住。
.onAppear { session.saveCheckpoint(persist: !session.logs.isEmpty) }
```

不改的后果——同一族的第二个症状：用户点「开始训练」，进训练页发现忘了东西，直接退出。今日页此时显示「上次训练没做完 · 停在第 1/13 步」，点进去是一组都没做的会话。`ResumePrompt` 因为 `stepIndex > 0` 这条挡住了不会问，但今日页的 `resumeHint` 没挡。

---

## 2. 现在有几个「开始训练」的入口

| 入口 | 代码 | 行为 |
|---|---|---|
| 今日页「开始」 | `AppShell.startWorkout()` | 新建会话 |
| 今日页「继续上次」 | `AppShell.resumeWorkout()` | 从断点续（唯一正确的路径） |
| 点通知 | `AppShell.openWorkout(_:)` | 新建会话，**不检查断点** |
| 短版训练 | `AppShell.startShort(minutes:)` | 新建会话 |
| Watch 点「已开始」 | `WatchNotificationHandler` | 只记 `openedDayIndex`，**什么都不做** |

会话是单例状态（同一时刻只能有一次训练在进行）。五个入口里三个新建、一个续、一个不做——**没有任何一处校验「已经有一次在进行了」**。这不是缺补丁，是缺那个唯一的裁决点。

### Watch 侧的现状

`WatchNotificationHandler` 收到通知只把 `dayIndex` 记下来，根视图消费时打一条日志（`.scratch` 里 W1.2 的产物）。注释写得很清楚：

> 对得上：App 本来就在训练页，什么都不用做
> 对不上：用户点的是攒下来的旧通知，别把今天这节当它

这条逻辑成立的前提是**iPhone 一定会先把会话开起来**。前提不成立时——用户带着手表去练、手机在包里——点「已开始」看到的是「请在 iPhone 上开始训练」。这是产品缺失，不是 bug：`WatchContext` 里只有当前会话，Watch 拿不到「今天的计划」，它没法自己开始。

---

## 3. 设计：一个裁决器

新文件 `DongKeCore/Workout/SessionLaunch.swift`。

### 3.1 输入

```swift
public struct ActiveSession: Equatable, Sendable {
    public var id: UUID
    public var dayIndex: Int
    public var startedAt: Date
    /// nil = 刚建、还没记过组
    public var checkpoint: WorkoutCheckpoint?
}

public enum SessionIntent: Equatable, Sendable {
    case startToday
    case openReminder(dayIndex: Int)          // 点通知
    case watchStart(dayIndex: Int?)           // 手表点「已开始」，nil = 不知道哪天
    /// 手表点「重新开始」。`sessionId` 是**手表看到的那一个**，
    /// 裁决器要靠它判断这条意图是不是已经处理过了（§4.2）。
    case watchRestart(dayIndex: Int, sessionId: UUID)
}
```

「只剩 N 分钟」的短版训练**不进这个枚举**：它选的是「今天」，跟 `startToday` 同一次裁决，差别只在构造会话时把 plan 换成 `SessionCompressor.compress` 的结果。把 `kind` 塞进 `SessionLaunch` 会让裁决器知道一件与「哪一次会话」无关的事。

`ActiveSession` 而不是直接用 `WorkoutCheckpoint`，是因为刚创建、还没记组的会话没有断点。用 checkpoint 当输入会让裁决器把「已经开始了」误判成「什么都没有」，于是再建一个。

### 3.2 输出

```swift
public enum SessionLaunch: Equatable, Sendable {
    case open(UUID)                      // 内存里那个就是它，什么都不做
    case resume(WorkoutCheckpoint)       // 从断点续
    case create(dayIndex: Int, planDate: Date?, origin: SessionOrigin)
    case abandonAndCreate(abandon: UUID, dayIndex: Int, planDate: Date?, origin: SessionOrigin)
    case blocked(SessionLaunchBlock)
}

public enum SessionLaunchBlock: String, Equatable, Sendable {
    case unknownDay     // 计划里没有这一天，或是休息日
    case staleRestart   // 要放弃的那个不是当前会话（含「什么都没有」）——意图已处理过
}

public enum SessionOrigin: String, Codable, Sendable {
    case phone
    case watch
}
```

`.open` 与 `.resume` 必须分开：前者是「不要动」，后者是「构造会话」。合并成一个 `resume` 会让每次点通知都重建会话对象，进度条重置、TTS 状态丢失，跟 §1 的症状一样。

### 3.3 规则表

设 `active` 为内存会话、`stored` 为落盘断点（`active == nil` 时才看它）。
`resumable` = `CheckpointValidator.validate(stored, plan.revision, now) == .resumable`。

| intent | 条件 | 结果 |
|---|---|---|
| `startToday` | `active` 存在且是今天的 | `.open(active.id)` |
| `startToday` | 其余 | `.create(今天, .phone)` |
| `openReminder(d)` | `active?.dayIndex == d` 且是今天的 | `.open` |
| `openReminder(d)` | 无 active、`stored.dayIndex == d`、resumable | `.resume(stored)` |
| `openReminder(d)` | 其余 | `.create(d, .phone)` |
| `watchStart(d)` | `active` 存在且是今天的 | `.open`（手表点开始 = 续上正在进行的） |
| `watchStart(d)` | 无 active、resumable | `.resume(stored)` |
| `watchStart(d)` | 其余，`d` 有值 | `.create(d, .watch)` |
| `watchStart(nil)` | 其余 | `.create(今天或下一节, .watch)`，跟 `startToday` 共用 `PlanCalendar.occurrence` |
| `watchRestart(d, s)` | `active` 存在且 `active.id == s` | `.abandonAndCreate(s, d, .watch)` |
| `watchRestart(d, s)` | 无 active、`stored?.sessionId == s` | `.abandonAndCreate(s, d, .watch)` |
| `watchRestart(d, s)` | `active.id != s` | `.blocked(.staleRestart)`——已经放弃过了 |
| `watchRestart(d, s)` | 无 active、`stored?.sessionId != s` | `.blocked(.staleRestart)`（`stored == nil` 也是这条） |
| 任意 | `d` 有值但不是训练日 | `.blocked(.unknownDay)` |

「是今天的」= `calendar.isDate(active.startedAt, inSameDayAs: now)`。不能只看 `dayIndex` 相等：App 在后台挂了一夜，`active` 的 dayIndex 还是昨天那个数字，但计划里的日期已经滚过去了。

`watchStart(nil)` 与 `startToday` 在休息日的行为**必须一致**：都走 `PlanCalendar.occurrence(on:in:)`，开计划里下一节。理由是两者都是「用户想练」，不该因为入口不同给出两种答案。第一版规则表把它们写成了「休息日挡住」，实现时被测试抓出来——`occurrence` 本来就会往后找最近一次训练。

两条隐含规则，要写进注释：

1. **`active` 优先于 `stored`。** 内存里的会话永远比落盘断点新（每次 `saveCheckpoint` 双写，`active` 是源头）。`active` 存在时不去读 `stored`，避免「断点比内存新」这种不存在的状态污染判断。
2. **`.create` 会丢旧断点。** UserDefaults 是单槽（`dk.workout.checkpoint`），新会话一落盘就把它替换掉；App Group 里虽然按 `checkpoint-{sessionId}.json` 分文件，但没有任何代码去读旧的那份。点通知切到别的一天时，之前那半截训练就没了——这是现有行为，本 spec 不改（见 §9 的「多断点」），但写在这里，别让下一个人以为是疏忽。

`planDate` 由调用方算：`.create` 用 `PlanCalendar.occurrence(of: dayIndex, anchoredAt: now, in: plan)?.date`，`.resume` 用 `PlanCalendar.occurrence(of: checkpoint.dayIndex, anchoredAt: checkpoint.startedAt, in: plan)?.date`（跟现在 `resumeWorkout` 一致）。裁决器不碰日历锚点，只决定走哪条路。

### 3.4 为什么放 Core

裁决器是纯函数，输入输出都是 `Sendable` 值类型，不碰 SwiftData、不碰 UI。这样：

- iPhone 的三个入口、Watch 的意图处理、以后可能的 Widget/App Intents，都调同一个函数
- 能写单测覆盖全表（§8），不用起模拟器
- 「为什么这次没续上」变成可断言的结果，不是散落在三个 `if` 里的隐性判断

---

## 4. 设计：一条意图通道

### 4.1 载荷

新文件 `DongKeCore/Watch/WatchIntent.swift`。

```swift
public struct WatchIntent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case start
        case restart
    }
    public var kind: Kind
    public var dayIndex: Int?
    /// restart：要放弃哪个会话。start：nil
    public var sessionId: UUID?
    public var planRevision: Int
    public var createdAt: Date
}
```

`WatchSyncKey` 加一个 `intent = "dk.watch.intent"`。传输沿用现有通道（`transferUserInfo`），**不加新机制**——两端已经有 `didReceiveUserInfo` 的实现和 964 条测试兜着的 outbox。

### 4.2 幂等的来源是 `sessionId`，不是去重表

原本打算做一张「已处理意图 id」的账本。不需要，因为裁决器本身就是幂等的：

| 重复投递的情形 | 第二次到达时 | 结果 |
|---|---|---|
| `watchStart` 重复 | `active` 已经是第一次建的会话 | `.open`，不新建 |
| `watchRestart(d, s)` 重复 | `active.id` 已经是新建的那个，不等于意图里的 `s` | `.blocked(.staleRestart)`，**不会再放弃一次** |
| `openReminder` 重复 | `active.dayIndex` 对上 | `.open` |

这就是为什么 `watchRestart` 必须把 `sessionId` 一起送来：没有它，第二次到达时裁决器看到「有个会话在」，会把这个**新**会话也放弃掉，用户点一下「重新开始」等于连点两次。

唯一漏的是「App 被杀 + 第一次没记任何组」：`active` 没了、断点没写，第二次 `watchStart` 会再建一个空会话。后果是内存里多一个对象，不落库（`persist` 在第一次 `appendLog` 才调），没有 `SessionEntity`。可接受，但加一道时间闸更省心：**`createdAt` 超过 5 分钟的意图直接丢弃**，同时回一条日志。

### 4.3 送达保证

| 场景 | 机制 | 说明 |
|---|---|---|
| Watch 与 iPhone 可达 | `sendMessage(_:replyHandler:)` | 秒级回执，用于「重新开始」的等待态 |
| 不可达 | `transferUserInfo` | 排队，等 iPhone 回来后送达 |
| iPhone App 未运行 | 系统后台唤起 | `didReceiveUserInfo` 会跑，见 §4.4 |

两条路都可能到达，所以幂等必须是裁决器级别的（§4.2），不能靠「只发一条」。

回执只带**裁决结果**（`SessionLaunch` 的粗粒度描述：新建了 / 无事发生 / 被挡住的 reason），不带会话内容。内容永远以 `WatchContext` 为准——否则会出现「回执说成功但 steps 还没到，Watch 拿旧 steps 记了一组」。不可达时没有回执，Watch 靠 8 秒超时退出等待态（§5）。

### 4.4 后台唤起的硬约束

`transferUserInfo` 在 iPhone App 未运行时，iOS 会启动进程投递。此时：

- `DongKeApp.init` 会跑（ModelContainer、各 Store 都建好了）
- **`AppShell` 的 `.onAppear` 不保证跑**（没有 UI 场景）

所以意图处理**不能依赖视图层**。`WatchIntentInbox.handle(_:)` 必须自己完成：

1. 从 `PlanStore` 读计划（`activePlan` 那份，含减载周处理）
2. 调 `SessionLaunchResolver.resolve(...)`
3. `.create` / `.abandonAndCreate` 时：构造 `WorkoutSession`、`saveCheckpoint()`（双写：UserDefaults + App Group）、`WatchContext.make`、`WatchSyncService.shared.send`
4. `.open` 时不做事——App 已经在跑，视图层自己会处理

这里有一处必须承认的不一致：后台创建的会话对象活不过这次进程唤醒（没人持有它）。用户之后打开 iPhone，`refreshResumeCandidate` 从断点读到它，走「继续上次」。**这是可接受的产品行为**：手表发起的训练，在 iPhone 上表现为「有一次没练完的记录，可以接着练」，而不是「iPhone 突然弹出训练页」。

### 4.5 「已开始」按钮的真实语义

`NotificationCategory.startTraining` 现在挂 `options: [.foreground]`——点它只负责打开 App。改造后：

- **iPhone 上点**：`NotificationRouter` 已经拿到 `dayIndex`，交给裁决器，`.resume` 或 `.create`（§1 的修法就是这个）
- **Watch 上点**（镜像通知）：App 启动后判断 `response.actionIdentifier == startTraining`，发 `WatchIntent(kind: .start, dayIndex: 通知载荷里的 dayIndex)`

Watch 侧不需要区分「打开 App」和「开始训练」两种点法吗？需要。点通知正文 = 想看进度；点「已开始」= 想开始。现在的 `WatchNotificationHandler` 不区分，两种都只是记 `dayIndex`。加上 `actionIdentifier` 判断即可。

---

## 5. Watch 侧的等待态

「重新开始」是唯一需要用户等的操作。状态机：

```
选择页 ──点「重新开始」──▶ 等待中(≤8s) ──收到 sessionId 变化──▶ 训练页
                              ├──超时──────────▶ 选择页 + 「iPhone 没响应，稍后再试」
                              └──staleRestart──▶ 退出等待，按现有上下文重渲染（无事发生）
```

- 确认信号是 **`context.checkpoint.sessionId` 变化**，不是 `replyHandler` 的返回值。理由：只有上下文到了，Watch 才有新会话的 `steps`；回执只说明意图被接受
- 8 秒是经验值，可调常量
- 等待期间禁止记组：日志的 `sessionId` 还是旧的，记了会写进要放弃的那个会话
- `staleRestart` 不弹错误：它说明这条意图之前已经生效了，只是确认信号丢了。直接按现有上下文重渲染（有会话就进训练页，没有就空态），比骂用户更对——可能真是连点了两下

`WatchResumeChoiceView` 的按钮布局（三个动作，小屏放得下）：

| 位置 | 文案 | 样式 |
|---|---|---|
| 1 | 继续练 | `borderedProminent`，品牌绿 |
| 2 | 重新开始 | `bordered` |
| 3 | 今天不练了 | `plain`，footnote |

---

## 6. 为什么不允许 Watch 单方面重开

技术上做得到：`WatchContext.checkpoint.steps` 是完整执行序列，Watch 换一个 `sessionId`、`stepIndex = 0` 就能「重新开始」，不用等 iPhone。

不做，理由有三条：

1. **会话的唯一真相在 iPhone。** 计划、日志库、`SessionEntity`、历史统计全在那儿。Watch 造一个 iPhone 不知道的 `sessionId`，那批日志回到 iPhone 时 `ingestRemoteLog` 的 `guard log.sessionId == id else { return false }` 会全部拒收，然后 `WatchLogInbox.drain` 的 `else if let setLogStore` 分支会把它们写进日志库——**留下一批没有对应会话的孤儿日志**（`DongKe/Services/WatchLogInbox.swift:29`）。这条路径现在不会走到，正是因为 Watch 从来只用 iPhone 给的 `sessionId`。
2. **`resolvedStepIndex = max(local, checkpoint.stepIndex)` 是本地保护，不是进度源。** 本地归零后，iPhone 下一次上下文一到就弹回原组。要让归零站得住，必须让 iPhone 认可一个新会话——也就是这个 spec 做的事。
3. **iPhone 不在附近时，用户并不是没有选择。** 选择页的「今天不练了」不需要 iPhone，退到空态、断点留着，明天接着来。

所以「重新开始」的失败态（8 秒超时）是**设计选择**，写在这里是为了让下一个人别把它当 bug 修掉。

---

## 7. 实现落点

| 文件 | 动作 | 内容 |
|---|---|---|
| `DongKeCore/Workout/SessionLaunch.swift` | 新增 | `SessionIntent` / `SessionLaunch` / `SessionLaunchResolver` / `SessionOrigin` |
| `DongKeCore/Watch/WatchIntent.swift` | 新增 | `WatchIntent` + `WatchSyncKey.intent` |
| `DongKeCoreTests/SessionLaunchTests.swift` | 新增 | 规则表全覆盖（§8） |
| `DongKe/Features/Workout/WorkoutSession.swift` | 改 | 加 `origin`；提取 `snapshot` 供裁决器读 |
| `DongKe/Features/Shell/AppShell.swift` | 改 | 四个入口（start / startShort / resume / openWorkout）收敛到 `apply(_ launch:)`（§1） |
| `DongKe/Features/Workout/WorkoutSession+State.swift` | 改 | `saveCheckpoint(persist: Bool = true)`：`persist == false` 时只广播、不写断点 |
| `DongKe/Features/Workout/WorkoutView.swift` | 改 | `onAppear` 传 `persist: !logs.isEmpty`（§1） |
| `DongKe/Data/Persistence/SessionEntity.swift` | 改 | 加 `origin: String?`（可选，轻量迁移） |
| `DongKe/Services/WatchSyncService.swift` | 改 | `didReceiveUserInfo` 加 `dk.watch.intent` 分支 |
| `DongKe/Services/WatchIntentInbox.swift` | 新增 | 意图处理，**不依赖视图层**（§4.4） |
| `DongKeWatch/WatchSyncService.swift` | 改 | 加 `WatchIntentSender`（sendMessage + transferUserInfo 兜底） |
| `DongKeWatch/WatchNotificationHandler.swift` | 改 | 区分 `actionIdentifier`，发 start 意图 |
| `DongKeWatch/WatchResumeChoiceView.swift` | 改 | 加「重新开始」+ 等待态 |
| `DongKe/Features/History/HistoryView.swift` | 改 | `origin == .watch` 时行内标一个「手表」 |

`SessionEntity.origin` 是可选字段，SwiftData 轻量迁移能处理。但按项目规矩（`docs/HANDOFF.md` §6.31），改 persistence 必须**装模拟器跑一次**——单测只覆盖 `DongKeCore`，谓词写错在这里表现为 NSException 硬崩。

---

## 8. 测试计划

`SessionLaunchResolver` 是纯函数，规则表逐格覆盖。按 `intent × 状态` 展开，至少这些：

| 组 | 用例 |
|---|---|
| `.open` 判定 | 同一天 active + startToday；active 存在 + watchStart；active 与断点 id 相同 |
| `.resume` 判定 | 无 active + 可续断点 + openReminder 同日；无 active + 可续 + watchStart |
| `.create` 判定 | 无可续 + startToday；可续但 dayIndex 不同 + openReminder；watchStart 带 nil dayIndex 落今天 |
| `.abandonAndCreate` | `active.id == 意图里的 sessionId` 时 restart；只有断点且 id 对上时 restart |
| `.blocked` | 休息日/不存在的一天；`watchRestart` 的 `sessionId` 与当前会话不符（含两者都没有） |
| 边界 | 断点跨天（不可续）时 openReminder 走 create；断点 `planChanged` 时走 create 而非 resume；`active` 是昨天建的（`startedAt` 跨天）时不 `.open`；`watchStart(nil)` 在今天休息时与 `startToday` 一样落到下一节 |
| `saveCheckpoint(persist:)` | `persist == false` 不改变断点内容、但仍会广播（用 `WatchSyncService` 的 mock 断言收到一次 context） |

变异验证（项目惯例，验证用例不是摆设）：

1. 把「`active` 优先」改成「`stored` 优先」→ 应至少一条红
2. 把 `openReminder` 的 `.resume` 分支删掉（退化成永远 create）→ §1 的 bug 用例必红
3. 把 `watchRestart` 的 `staleRestart` 判据（`active.id == s`）删掉 → 连点两次的用例必红
4. 把 `saveCheckpoint` 的 `persist` 参数忽略掉（永远写）→ 空断点用例必红

Watch 侧的等待态在 Core 里也要可测：把「是否还在等」抽成 `RestartWaitState`（纯值 + 超时判定），不塞进 View。

**回归验证要落到模拟器上**：§1 的实测步骤（`DK_SEED_CHECKPOINT=1` + `DK_OPEN_REMINDER=0`）修好后必须重跑一遍，确认训练页停在第 4 步、断点的 `stepIndex` 仍是 3。这条不在单测覆盖范围里——`openWorkout` 是视图层方法，只能靠这个钩子。

---

## 9. 不做

| 项 | 为什么 |
|---|---|
| Watch 单方面重开（离线也能重开） | §6 |
| 多断点并存（同时保留两天的进度） | 断点存储是单槽，改多槽要动 `WorkoutCheckpointStore` 的键设计与今日页入口。现在没有用户诉求支撑 |
| 意图去重账本 | 裁决器天然幂等（§4.2），账本是冗余状态 |
| `startedFrom` 写进 `WatchContext` | Watch 不需要知道自己这轮是谁起的；唯一的消费者是历史页，读的是 `SessionEntity` |
| Watch 端 AppIcon / 资源目录 | 属于发布准备，与本 spec 无关（W2.2 已经踩过一次，见提交 `57588cd`） |
| 通知正文改成「深蹲 4 组」 | 影响已发版 1.1.0 的通知体验，单独定 |

---

## 10. 实施顺序

1. `SessionLaunch` + 单测（纯 Core，不动 UI）
2. **§1 止血**：`openWorkout` 接裁决器 + `onAppear` 加 `persist` 判据。做完立刻重跑 §8 的模拟器回归，确认第 4/13 步不再归零。这一步独立可交付
3. `WatchIntent` + 两端通道 + `WatchIntentInbox`（含后台唤起路径）
4. Watch 的「重新开始」与等待态
5. `SessionEntity.origin` + 历史页标签（唯一动 persistence 的一步，单独提交，装模拟器验）

第 2 步之后到第 5 步之前，`origin` 一律按 `.phone` 处理——裁决器已经带着这个参数，只是没有消费者。这样每一步都能单独提交、单独回滚。
