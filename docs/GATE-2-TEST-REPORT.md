# Gate 2 · 测试门报告

> 日期：2026-10-22
> 工程：`DongKe.xcodeproj`（XcodeGen 生成）
> 目标：iPhone 18 Pro 模拟器 / iOS 27.0
> 命令：`xcodebuild -project DongKe.xcodeproj -scheme DongKe -destination 'platform=iOS Simulator,id=65E2C3C1-9BDA-49A7-907F-C05AF893D6B6' -parallel-testing-enabled NO test`

## 1. 结果总览

| 指标 | 数值 |
|------|------|
| 测试总数 | 52 |
| 失败（红） | 38 |
| 通过（绿） | 14 |
| 崩溃 | 0 |
| 结果 | **TEST FAILED（预期）** |

这 38 条红是**实现为空导致的失败**，不是测试写错。测试门的目的就是先把行为钉死，再让实现逐条转绿。

## 2. 分层结果

| Suite | 测试数 | 红 | 绿 | 覆盖行为 |
|-------|--------|----|----|----------|
| Weekday | 5 | 0 | 5 | 周一=1 与 Calendar 周一=2 的换算 |
| PlanJSONExtractor | 5 | 4 | 1 | 代码围栏、前后说明、字符串内大括号、单元素数组、无 JSON |
| PlanDecoder | 4 | 2 | 2 | 严格解码、未知 schemaVersion、缺字段、宽松补默认 restSec=60 |
| PlanValidator | 8 | 7 | 1 | 组数 0/21、休息 -1/601、7 天、daysPerWeek、weekday 一致性 |
| FreeTextPlanParser | 6 | 6 | 0 | 中文组数/次数/时长/每侧/循环/无关文本 |
| WorkoutFlowModel | 4 | 4 | 0 | 3 动作×3 组、循环 3 轮、超级组 0 休息、休息日 |
| RestTimerStateMachine | 8 | 8 | 0 | 8 条不变量：绝对时间、单次结束、暂停/恢复、加时、跳过、后台跳跃 |
| WeeklyScheduleGenerator | 5 | 3 | 2 | 训练日、无时间回退、跨午夜提前、休息日、关闭 |
| CompletionRateCalculator | 7 | 5 | 2 | 0 分母、完成率、clamp、连续达标天数 |

> 14 条绿只代表「Weekday 映射」与「nil / 空值 / 抛错」这类断言，不代表实现完成。

## 3. 红转绿顺序（实施阶段）

1. `PlanJSONExtractor` → `PlanDecoder` → `PlanValidator` → `PlanNormalizer`
2. `FreeTextPlanParser`
3. `WorkoutFlowModel`
4. `RestTimerStateMachine`
5. `WeeklyScheduleGenerator`
6. `CompletionRateCalculator`
7. `PoseInterpolator` + 18 个动作骨架数据
8. UI 与持久化（不在这 52 条内，另做端到端验证）

## 4. 尚未覆盖（后续补）

- SwiftData 持久化与删除链路
- UNUserNotificationCenter 真实排程（模拟器不可靠，需真机）
- AI 直连的 401/429/超时/非 https 错误映射
- 12 个页面的 UI 与三条主链路 UI 测试
- 骨架渲染的视觉验收（辨识度）

## 5. 门禁结论

| 项 | 状态 |
|----|------|
| 工程可生成、可编译 | 通过 |
| 测试可运行、结果可复现 | 通过 |
| 红基线已建立 | 通过 |
| 实现转绿 | 待放行 |

**Gate 2 待你放行。放行后我开始把 38 条红逐条转绿，再进入 UI 实施。**

---

## 6. 转绿结果（2026-10-22 21:25）

| 指标 | 数值 |
|------|------|
| 测试总数 | 52 |
| 通过 | 52 |
| 失败 | 0 |
| 结果 | `Test run with 52 tests in 9 suites passed` / **TEST SUCCEEDED** |

命令：`xcodebuild -project DongKe.xcodeproj -scheme DongKe -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -parallel-testing-enabled NO test`

### 6.1 本轮唯一一处「测试对、模型错」

`Weekday` 原本声明为 `Int` rawValue（`monday = 1`），合成 Codable 按整数解码；而 `plan-schema.json` 的契约是字符串 `"monday"`。表现为 `PlanDecoder.decode(validPlanJSON())` 抛 `typeMismatch: days[0].weekday`，被 `decode` 的兜底 catch 包成 `schemaMismatch`。

修法：保留 `Int` rawValue（`Weekday(rawValue:)` 的序号语义被测试与排程依赖），另写 `init(from:)` / `encode(to:)` 走字符串名，并加 `init?(name:)` 与 `englishName`。解码同时兼容整数形式，供旧数据兜底。

### 6.2 各层落地要点

| 层 | 实现要点 |
|---|---|
| `PlanJSONExtractor` | 代码围栏优先；无围栏时按引号感知的括号配对取首个平衡对象；单元素数组拆壳 |
| `PlanDecoder` | 严格解码 + `schemaVersion == 1` 校验；宽松路径在 JSON 层补 `restSec=60` 等缺省并逐条记 issue |
| `PlanValidator` | 组数 1–20、休息 0–600、轮数 1–20、7 天与 `dayIndex`/`weekday` 一致、`daysPerWeek` 与训练日数一致 |
| `FreeTextPlanParser` | 逐行：星期标记 → 循环轮数 → 动作行；正则依次剥离休息 / 组×次 / 组 / 次 / 秒，剩余文本作动作名 |
| `WorkoutFlowModel` | 循环/超级组按 `rounds` 展开，轮间插 `roundBreak`（末轮不插），块间插 `blockBreak` |
| `RestTimerStateMachine` | 绝对 `endAt`；`tick` 越过终点只结算一次；暂停存剩余；加时同时延长 `endAt` 与 `totalSeconds` |
| `WeeklyScheduleGenerator` | 提前量跨午夜时 `triggerTime` 回绕到前一日并同步回退 `weekday` |
| `CompletionRateCalculator` | 分母 0 返 nil；完成率 clamp 到 0…1；连续天数阈值 0.8，今日未达标时从昨日回溯 |
| `PoseInterpolator` | 关键帧线性插值，`phase` clamp 到 0…1，关节缺失时取目标帧 |

### 6.3 仍未覆盖

- 18 个动作的骨架数据（`figure-specs.json`）尚未编写，`PoseInterpolator` 只有算法没有数据。
- 第 4 节列出的持久化、通知真实排程、AI 错误映射、UI 均未开始。

