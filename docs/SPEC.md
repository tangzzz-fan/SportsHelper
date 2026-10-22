# Spec - 动刻 DongKe v1.0

> 生成日期：2026-10-22
> 基于：PRD v1.0 + ARCHITECTURE v1.0 + UIUX v1.0 + design-tokens v1.0 + plan-schema v1
> 状态：待用户确认

---

## 1. 产品定义

| 项 | 内容 |
|----|------|
| 一句话 | 把 Claude / DeepSeek 写的居家减脂运动计划，变成每天按点提醒、按动作与组数执行、带动作图示的训练日程。 |
| 目标用户 | 34 岁居家程序员，久坐、减脂；运动基础 / 器械 / 可用时长在启动引导中采集。 |
| 核心问题 | AI 计划是散文，不是结构；到点没人拉，组间休息靠心算，做不动没出口，第三周计划就死了。 |
| 差异化 | 不生成计划，只接管执行：导入 → 结构化 → 到点提醒 → 逐组引导 → 打卡。 |

---

## 2. MVP 范围（锁定）

| 优先级 | 功能 | 验收标准摘要 | RICE |
|--------|------|-------------|------|
| P0 | F1 启动引导 | 5 屏采集 10 个字段，可跳过，≤60 秒 | 10.00 |
| P0 | F2 训练提醒 | 每个训练日一条按周重复的本地通知，提前 5 分钟，正文含动作数与时长 | 5.40 |
| P0 | F3 结构化日程 | 计划 → 周一至周日 7 天条目；休息日占位；支持循环 / 超级组 | 3.60 |
| P0 | F4 训练执行 | 逐组推进、组间休息倒计时、+15s / 跳过 / 降阶、锁屏后回前台按绝对时间重算 | 4.32 |
| P0 | F5 粘贴导入 | JSON 严格解析 + 自由文本启发式；解析结果必须人工校正后才能保存 | 4.32 |
| P0 | F6 打卡与完成率 | 每组完成即落库；完成率 = 完成组数 / 计划组数；历史按周展示 | 3.73 |
| P0 | F7 动作图示 | 18 个核心动作：参数化线稿人形 3 关键帧 + 3 条要点 + 1 条低阶替代 | 2.80 |
| P0 | F10 直连 AI（BYOK） | 用户在设置里填 Base URL + Key，App 内生成计划；Key 存 Keychain | 1.37 |

**范围裁决（总监定，需用户在方案门确认）**

| 裁决 | 结论 | 理由 |
|------|------|------|
| 直连 AI | **进 MVP**，收敛为 OpenAI 兼容单端点 + 非流式 | 用户明确要求「可以直连」；不做生成引擎，只做「调用 + 解析」 |
| 动作库规模 | **18 个**（schema 已锁定的 catalogId） | 60 个矢量图会把 MVP 拖长；18 个覆盖居家核心动作，库外用文字要点兜底 |
| 久坐提醒 | **移出 MVP，列 P1** | 用户原始诉求只提训练提醒；避免范围蔓延 |
| 最低 iOS | **18.0** | SwiftData 成熟度与覆盖率的最优解（覆盖 93% 在用 iPhone） |
| 动作素材 | **开源素材库 `bryllim/workout-guide` 的单色线条插画**（CC BY-SA 4.0，18/18 覆盖） | 用户裁决接受动画素材；本轮不上架，share-alike 处置延后，素材走 `FigureSource` 可换源（下一顺位：公有领域 `yuhonas/free-exercise-db`） |
| 主题 | **浅色为主 + 深色完整** | 与「健身房深色」竞品拉开第一眼差异 |

---

## 3. 明确不做（Out-of-Scope）

| 不做 | 原因 | 何时考虑 |
|------|------|----------|
| 饮食 / 蛋白质统计（拍摄 + 语音） | 用户已排为后续；本期专注运动闭环 | P1 |
| 久坐微运动提醒 | 非原始诉求，且需额外通知类型与权限解释 | P1 |
| 视频动作指导 | 矢量骨架已能表达动作形状，视频的存储与首帧加载伤害「打开就开始」 | P2 |
| 60 个动作全量图示 | 生产成本高，18 个 + 文字兜底已覆盖居家场景 | P1 扩充 |
| 账号 / 云同步 / 自建后端 | 单机本地优先即可闭环，且避免密钥代管与计费 | 不做 |
| 社交 / 排行 / 分享海报 | 主画像是独居居家办公者，社交压力不起作用 | 不做 |
| 会员 / 内购 / 支付 | 先验证执行闭环，再谈变现 | 不做 |
| Apple Watch / HealthKit / Live Activity / AlarmKit | 与「纯 iPhone、零硬件」立场冲突；Live Activity 需额外 Target | P2 |
| iPad / 横屏 / 多语言 | 手机竖屏为唯一目标 | 不做 |
| 第三方图标库 | SF Symbols 唯一图标源，不引入图标包 | 不做 |

---

## 4. 技术架构（锁定）

| 层 | 技术 | 版本 | 锁定原因 |
|----|------|------|----------|
| 工具链 | Xcode | 27.1（本机） | 已安装，iOS 27 SDK 可编译 iOS 18 目标 |
| 语言 | Swift 6 language mode | 6 | 严格并发检查，抓 `ModelContext` 越界 |
| 最低系统 | iOS | 18.0 | SwiftData `#Index` / `#Unique` 可用；覆盖 93% |
| UI | SwiftUI | iOS 18 SDK | 与 SwiftData / Charts / 通知同源，零依赖 |
| 持久化 | SwiftData | iOS 18 | 声明式绑定，5 张表足够 |
| 通知 | UserNotifications | iOS 18 | `UNCalendarNotificationTrigger(repeats: true)`，单计划 ≤7 条 |
| 图表 | Swift Charts | iOS 18 | 历史完成率趋势，零依赖 |
| 密钥 | Security.framework（Keychain） | iOS 18 | Key 只存本机，`AfterFirstUnlockThisDeviceOnly` |
| 图标 | SF Symbols | iOS 18 SDK | 全项目唯一图标源，经 `Icons.swift` 单一入口 |
| 字体 | SF Pro / PingFang SC + 系统等宽 | 系统 | 零打包字体；倒计时用 `.monospacedDigit()` |
| 测试 | Swift Testing + XCTest（UI） | Xcode 27.1 | 纯逻辑用 `@Test`，UI 三条主链路用 XCTest |
| 第三方依赖 | 无 | — | 零 Package / Pod / Carthage |

**分层与依赖方向**：`App → Features / Services / Data → Domain`；`Domain` 只 import Foundation；`Features` 禁止 import SwiftData；端口协议在 `Domain/Ports/`。

**目录**：按 `docs/ARCHITECTURE.md` §4.2 点名文件落地。单文件 ≤300 行，生产代码零注释。

---

## 5. 外部接口（唯一网络出口）

| Method | Path | 功能 | 认证 | 请求体 | 响应体 |
|--------|------|------|------|--------|--------|
| POST | `{userBaseURL}/chat/completions` | 生成周计划 | `Authorization: Bearer {key}` | `model`, `messages`, `temperature: 0.2`, `response_format` | `choices[0].message.content` 为符合 `plan-schema.json` 的 JSON 字符串 |

- `response_format` 三级降级：`json_schema(strict)` → `json_object` → 纯提示词；三级都失败不重试第四次。
- 不启用流式；连接 15s / 总 60s；仅对 429 / 5xx / timeout 各重试 1 次（退避 2s）。
- 错误必须映射为可执行中文提示（缺 Key / URL 非 https / 401 / 429 / 5xx / 超时 / 网络不通 / 空响应 / 非 JSON / Schema 不符）。
- 无自建后端；无账号；无遥测 SDK。

---

## 6. 数据表（锁定）

| 表 | 核心字段 | 索引 | 关联 |
|----|----------|------|------|
| `PlanRecord` | id, createdAt, updatedAt, isActive, sourceRaw, schemaVersion, planJSON, title, daysPerWeek, goalRaw | `#Unique id`；`#Index updatedAt`；`#Index isActive` | 无关系链；`planJSON` 为完整 `WorkoutPlan` |
| `SessionRecord` | id, planId, planDayId, startedAt, finishedAt, statusRaw, plannedSets, completedSets, totalRestSeconds | `#Unique id`；`#Index startedAt`；`#Index planDayId` | 用 `planId` / `planDayId` 普通字段关联 |
| `SetLogRecord` | id, sessionId, prescriptionId, setIndex, targetTypeRaw(reps/seconds), statusRaw(done/downgraded/skipped), plannedValue, actualValue, skipReasonRaw, completedAt, rpe | `#Unique id`；`#Index sessionId`；`#Index([prescriptionId, completedAt])` | 用 `sessionId` 普通字段关联；三态是完成率与「做不动」统计的唯一依据 |
| `ProfileRecord` | singletonKey, heightCm, weightKg, age, sexRaw, goalRaw, levelRaw, availableWeekdays, sessionMinutes, equipment, injuries, onboardedAt | `#Unique singletonKey` | 单行 |
| `ReminderSettingsRecord` | singletonKey, enabled, leadMinutes, soundEnabled, defaultTime | `#Unique singletonKey` | 单行 |

**Bundle 只读资源**：`exercises.json`（18 条动作：名称 / 别名 / 肌群 / 器械 / 难度 / 3–5 条要点 / 2–3 条常见错误 / `figureSpecId` / 默认目标）、`figure-data.json`（构建期由素材 SVG 生成：18 个动作各 3 帧矢量路径 + 1 条 `_generic` 占位图；静力动作**数据上也是 3 帧**，取第 1 帧是渲染期决定）。

**计划契约**：`docs/plan-schema.json` 为唯一真相；AI 输出、粘贴 JSON、备份导出、SwiftData `planJSON` 四条链路共用；反 null，所有字段必填，空值用 `""` / `[]` / `0`。

---

## 7. 页面清单（锁定）

| # | 页面 | 入口 | 核心组件 | 数据 |
|---|------|------|----------|------|
| 1 | 引导问卷（5 屏） | 首次启动 | 步进器、选项 chip、跳过 | UserProfile |
| 2 | 今日 | Tab 1 | 今日训练卡、下次训练、通知缺失条 | Plan + Session |
| 3 | 训练执行 | 今日 / 通知深链 | 动作剪影图示、组进度、完成本组、做不动 | WorkoutFlowModel |
| 4 | 休息计时 | 训练页 sheet | 88pt 倒计时、环形进度、+15s / 跳过 | RestTimerStateMachine |
| 5 | 完成总结 | 训练结束 | 完成率 / 降阶率 / 跳过率 三数并列、总时长 | Session + SetLog |
| 6 | 计划 | Tab 2 | 7 天列表、训练日 / 休息日、当前计划 | PlanRecord |
| 7 | 计划导入 | 计划页 / 今日空态 | 粘贴框、JSON / 文本识别、AI 生成、复制提示词 | ImportViewModel |
| 8 | 计划预览与校正 | 导入后必经 | 逐动作行、issue 高亮、编辑 sheet、保存 | ParsedPlanDraft |
| 9 | 动作库 | 计划页 | 18 动作分组列表 | exercises.json |
| 10 | 动作详情 | 动作库 / 训练页 | 剪影图示、要点、常见错误、低阶替代 | ExerciseCatalogItem |
| 11 | 记录 | Tab 3 | 周完成率图、连续天数、历史列表 | Session + SetLog |
| 12 | 设置 | 今日页导航栏 | 提醒时间、AI Base URL / Key、清空数据、关于 | ReminderSettings + Keychain |

三 Tab：今日 / 计划 / 记录；设置藏今日页导航栏；休息计时是 sheet，不接管全屏。

---

## 8. 设计 Token（锁定）

| 项 | 值 |
|----|-----|
| 主色（强调） | `#0E7C66`（浅色）/ `#34B39A`（深色），深青绿；每屏可见 ≤2 处 |
| 页面底色 | `#F5F7F6`（浅色）/ `#0C1210`（深色） |
| 主文本 | `#14201D`（浅色）/ `#E4EBE8`（深色） |
| 成功 / 警告 / 危险 | `#17803F` / `#9A5D08` / `#B01F2E`（浅色），深色见 token |
| 字体 | SF Pro Display/Text + PingFang SC + 系统等宽；零打包字体，倒计时与训练主数字用 `.system(design: .monospaced)` + `.monospacedDigit()` |
| 图标 | SF Symbols（iOS 18 SDK），经 `Icons.swift` 唯一入口；禁 emoji、禁第二套 |
| 圆角 | 常规控件 4 / 6 / 10 / 14；卡片 20（上限）；玻璃浮层 28（sheet）/ 36（卡片）/ 40（浮岛）。玻璃层遵守同心圆角：内层 = 外层 − 内边距，禁止内外同值 |
| 触控 | 常规 ≥44pt；训练中 ≥56pt；主按钮 64pt |
| 主题 | 浅色为主 + 深色完整；语义 token 自动适配 |
| 动效 | 80 / 150 / 200 / 240 / 300ms；`cubic-bezier(0.2,0,0,1)`；禁止弹跳 |

完整值见 `docs/design-tokens.json`（28 个语义色 × 明暗双值）。

---

## 9. 验收标准（EARS）

| 编号 | 功能 | EARS 验收标准 | 优先级 |
|------|------|---------------|--------|
| AC-01 | 引导 | While 首次安装且未完成引导，When 打开 App，系统**必须**进入 5 屏引导，且全程可跳过 | P0 |
| AC-02 | 引导 | When 用户完成引导，系统**必须**保存 UserProfile 并落到今日页，不得再次出现引导 | P0 |
| AC-03 | 导入 | When 用户粘贴含 `哑铃深蹲 4组×12次，休息90秒` 的文本并确认，系统**必须**在 3s 内（P95）展示校正页，且该行显示 4 组 / 12 次 / 90 秒 | P0 |
| AC-04 | 导入 | When 用户粘贴合法 JSON（含 `days` 数组），系统**必须**走严格解码，跳过正则解析，字段无错位 | P0 |
| AC-05 | 导入 | If 文本中没有任何可识别动作，系统**必须**提示「未能识别出动作」并给出手动添加入口，不得报「系统错误」 | P0 |
| AC-06 | 校正 | When 用户修改某一行组数并保存，系统**必须**只更新该行，其他行不变，保存后日程使用新值 | P0 |
| AC-07 | 引导 | When 用户走到引导第 5 屏并选择提醒时间，系统**必须**在此刻请求通知权限（有上下文），拒绝后显示「已关闭，去系统设置打开」+ 跳转按钮，不阻塞其他功能 | P0 |
| AC-08 | 提醒 | When 到训练日前 5 分钟，系统**必须**发出本地通知，正文含当日动作数与预计时长，点击直达训练页 | P0 |
| AC-09 | 提醒 | When 计划被替换或删除，系统**必须**先清除 `dk.plan.` 前缀下的旧通知再重排，不得叠加 | P0 |
| AC-10 | 训练 | When 用户进入训练页，系统**必须**立即显示当前动作、第 1 组 / 总组数、目标次数或时长、动作剪影图示与要点，无需额外点击 | P0 |
| AC-11 | 训练 | When 用户点「完成本组」，系统**必须**立即落库该组，并进入 restSec 秒休息倒计时 | P0 |
| AC-12 | 训练 | When 休息倒计时归零，系统**必须**触发触觉 + 声音，并自动切到下一组 | P0 |
| AC-13 | 训练 | If 用户锁屏 90 秒后回前台，系统**必须**按绝对时间重算，剩余时间不得出现负数或逐秒追赶 | P0 |
| AC-14 | 训练 | When 用户点「这组做不动」并选「减一半次数」，系统**必须**只改本组目标，记录为降阶完成，不影响后续组 | P0 |
| AC-15 | 训练 | If 训练中 App 被杀，When 30 分钟内重开，系统**必须**恢复到中断时的组与剩余休息，已完成组不丢 | P0 |
| AC-16 | 总结 | When 用户结束训练，系统**必须**生成完成率 = 完成组数 / 计划组数（降阶计入完成，跳过不计） | P0 |
| AC-17 | 历史 | When 用户完成当天全部组，系统**必须**将当天标记为完成，连续天数 +1 | P0 |
| AC-18 | AI | When 用户填 `http://` 开头的 Base URL 并保存，系统**必须**立即拒绝并提示「接口地址需要以 https:// 开头」，不发请求 | P0 |
| AC-19 | AI | When 用户 Key 返回 401，系统**必须**提示「API Key 被拒绝」且不保存 Key | P0 |
| AC-20 | 离线 | While 无网络，When 用户执行导入 / 训练 / 打卡，系统**必须**全部可用，仅在用户主动点「AI 生成」时提示网络不可用 | P0 |
| AC-21 | 主题 | When 系统切换到深色模式，系统**必须**所有页面使用深色 token，正文对比度 ≥4.5:1 | P0 |
| AC-22 | 图标 | 全项目**不得**出现 emoji 作为功能图标；图标只从 `Icons.swift` 的 SF Symbols 白名单取 | P0 |

---

## 10. 边界与约束

| 类别 | 约束 |
|------|------|
| 平台 | iPhone 竖屏，iOS 18.0+；不做 iPad / 横屏 |
| 数据 | 单机本地；无账号、无云同步、无后端；App 内提供「清空全部数据」 |
| 网络 | 核心链路离线可用；唯一网络出口是用户自填的 AI 端点；强制 https |
| 输入 | 粘贴上限 64KB；超限拒绝并提示；解析在后台 Task 执行，不阻塞主线程 |
| 通知 | 单计划 ≤7 条重复触发器；休息计时临时占 1 条；绝不调用 `removeAllPendingNotificationRequests()` |
| 性能 | 冷启动到首页 <1.5s；解析 P95 <3s（≤50 动作）；组间切换 <100ms |
| 代码 | 单文件 ≤300 行；生产代码 0 注释；无硬编码颜色 / 字号 / `Image(systemName:)` 字面量 |
| 设计 | 禁 emoji 图标、禁紫→粉渐变、禁弹跳缓动、禁空洞占位文案 |
| 测试 | Domain 纯逻辑必须有测试；UI 只测三条主链路；测试文件允许注释 |

---

## 11. 内嵌已知坑

| 坑 | 指纹 | 根因 | 修法 |
|----|------|------|------|
| 待触发通知上限 64 条，超出静默丢弃 | UserNotifications | 系统只保留最先触发的 64 条，`add()` 不报错 | 每个训练日 1 条重复触发器，单计划 ≤7；按前缀清理后重排 |
| `Weekday` 与 `Calendar` 语义相反 | Swift / Calendar | Calendar 的 `weekday` 1=周日，计划 1=周一 | 统一走 `Weekday.systemWeekday = (mondayBased % 7) + 1`，必须有测试 |
| 后台 Timer 停止导致休息倒计时错乱 | iOS 生命周期 | App 进后台后进程挂起，Timer 不跑 | 存 `endAt` 绝对时间 + 本地通知；回前台按 wall clock 重算 |
| 前台默认不展示通知 | UNUserNotificationCenter | 未实现 `willPresent` 时前台静默 | 显式返回 `[.banner, .sound]` |
| OpenAI strict 模式不支持 `minimum` / `pattern` | JSON Schema | Structured Outputs 只支持子集 | Schema 只表达结构，取值范围交给 `PlanValidator` |
| LLM 返回 null / 缺字段 | AI 输出 | 可空字段三态偏差 | 契约要求全字段必填，空值用 `""` / `[]` / `0` |
| SwiftData 深关系链级联删除缺陷 | SwiftData | 多关系级联删除已知问题 | 计划扁平存 JSON；不建 `@Relationship`；显式按序删除 |
| 全角引号 / 尾随逗号 / 代码围栏 | 粘贴解析 | AI 输出常见脏格式 | 引号感知括号配对；先清洗再解码；每条一个测试 |
| 模拟器 Keychain 跨运行保留 | Security | 模拟器 Keychain 不随 App 删除清空 | 测试 teardown 删除自己的 key |
| 素材门禁红被误判为回归 | 生成产物 `figure-data.json` | 生成器静默产出空帧或退化包围盒时，界面表现为「某动作图是空的」而非构建失败 | 门禁在生成期而非运行期：条目数必须 19（18 + `_generic`）、每个动作 3 帧、路径非空、包围盒有限且为正；任何一条不满足即构建失败 |
| SVG 画布留白导致图示忽大忽小 | 素材 `512×512` 方图 | 各动作人形占画面比例不同（俯卧撑横、深蹲竖） | 渲染期按路径 `boundingRect` 等比 fit，包围盒取三帧并集，画面尺寸不随帧变化 |

---

## 12. 端到端验证步骤

```bash
cd /Users/tango/Developments/SportsHelper

xcodegen generate
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

xcrun simctl install booted <DerivedData>/Build/Products/Debug-iphonesimulator/DongKe.app
xcrun simctl launch booted app.dongke.ios
```

**主成功流**：冷启动 → 5 屏引导 → 粘贴示例 JSON → 校正页零 issue → 保存 → 今日页出现训练 → 开始训练 → 完成一组 → 休息倒计时 → 全部完成 → 总结完成率 100% → 历史页一条记录。

**关键错误流**：粘贴「今天练一下胸吧」→ 校正页提示未识别 → 手动添加；Base URL 填 `http://` → 立即拒绝；通知权限拒绝 → 设置页显示跳转；训练中杀 App → 重开恢复断点。

---

## 13. 变更记录

| 日期 | 变更 | 原因 | 影响 |
|------|------|------|------|
| 2026-10-22 | 初版 | Phase 1.5 | 锁定 MVP 范围与技术契约 |
| 2026-10-22 | 直连 AI 保留 MVP；动作库 60→18；久坐提醒移出；iOS 16→18 | 三文档冲突裁决 | 范围收敛，工期可控 |
| 2026-10-22 | 动作图示由「自绘 12 关节骨架」改为开源素材库实心剪影（3 帧 SVG → 构建期转 Path），静力动作取第 1 帧，素材走 `FigureSource` 可换源；界面确立真玻璃材质，iOS 26 原生 / iOS 18 近似双路径；§8 圆角补玻璃浮层档位 | 用户裁决：接受动画素材、要求玻璃质感、且部署版本维持 iOS 18 | 图示管线与界面材质整体替换，旧骨架体系作废 |
| 2026-10-22 | 主色定为深青绿 `#0E7C66` / `#34B39A`；动作图示定为自绘参数化骨架（不用第三方素材）；SetLog 改三态；通知权限在引导第 5 屏后请求；跳过并顺延列 P1 | 最终冻结裁决 | 与 design-tokens v2 对齐，消除授权与额度风险 |
