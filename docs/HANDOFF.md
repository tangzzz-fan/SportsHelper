# 换机接手说明

本文是给人看的交接单，不是规范。规范只有两份：`docs/FROZEN-BASELINE.md` 与 `docs/SPEC.md`。**主流程看 `docs/FLOW.md`**（唯一维护点，改入口或保存时机同步改它）。

## 1. 当前状态

| 项 | 状态 |
|---|---|
| 方案门 | 已放行（用户「方案通过」） |
| 文档 | 已冻结。PRD / ARCHITECTURE / UIUX 只作存档依据，冲突时以 FROZEN + SPEC 为准 |
| 工程 | `project.yml`（XcodeGen）已可生成 `DongKe.xcodeproj`；DongKeCore framework + DongKe app + DongKeCoreTests + DongKeUITests；`Shared/A11yIdentifiers.swift` 同时编进 App 与 UI 测试 |
| 代码 | Domain 已实现（JSON 抽取 / 解码 / 校验 / 归一 / 自由文本解析 / 执行流 / 休息状态机 / 周排程 / 完成率 / 计划生成 / 导入编排 / 动作库 / 图示 / AI 契约 / 断点策略 / 通知负载）+ 图示模块（开源素材 / 可换源 / 点按播放）+ 玻璃材质层 + AI 直连（Keychain / 提示词 / 三级降级 / 错误映射）+ 训练执行收尾（组级明细 / 跳过三态 / 30 分钟断点续练 / 前台通知与深链 / 触觉声音）+ 设置页收尾（AI 配置 / 关于 / 清空全部数据）+ 今日页提醒健康条 + 字号令牌 `Typography`（Dynamic Type 到 AX5）+ 训练页要点与「做不动」三选 + 记录页周图改用 Swift Charts。SPEC §7 的 13 页清单**全部落地**：引导 5 屏、今日、训练执行、休息、完成总结、计划、计划导入（粘贴 → 校对 → 保存 / AI 生成 + 一句话语音 / 文字）、理解确认、动作库、动作详情、记录、设置（提醒 + AI + 关于 + 清空）+ 训练播报（ticket 07–09）与语音输入（ticket 06）。工程侧补上了 `Assets.xcassets`（AppIcon，`Tools/IconRender` 可重渲）与 `PrivacyInfo.xcprivacy`（见 §6.24） |
| 数据 | 训练记录、组级明细（三态 + 跳过原因）、档案、计划走 SwiftData；断点存在 UserDefaults `dk.workout.checkpoint`（30 分钟内有效）；提醒按计划排程（≤7 条、先清后排）+ 休息计时临时通知；计划由引导档案生成，也可粘贴文本 / JSON 导入，或走用户自填的 AI 端点生成 |
| 测试 | **487 条 Swift Testing 全绿**（`-only-testing:DongKeCoreTests`）+ **16 条 UI 测试**（`-only-testing:DongKeUITests`，默认不跑，见 §6.21）；AI 契约 44 条、AI 传输层 15 条、断点续练 9 条、通知负载 6 条、提醒健康度 9 条、导入标题 3 条、距离型目标 6 条、完成口径 13 条、解析边界 86 条、名词覆盖 16 条、一句话意图 36 条、播报文案 25 条、播报闸门 11 条、播报流程 16 条、语音输入 42 条 |
| Gate 2 | 已放行并全部转绿 |
| 远端 | `git@github.com:tangzzz-fan/SportsHelper.git`，main |

## 2. 新机器要装什么

| 依赖 | 要求 | 为什么 |
|---|---|---|
| Xcode | 27.1（iOS 27 SDK） | 目标 iOS 18.0，Swift 6 language mode + 完整并发检查 |
| XcodeGen | 任意近期版本，`brew install xcodegen` | 工程文件由 `project.yml` 生成，`.xcodeproj` 不入库 |
| iOS 18 模拟器 | 任一 iPhone 机型 | 跑测试与截图 |
| Git | 能推 https 或 ssh | 续提交。https 偶发 `HTTP2 framing layer`，遇错加 `--http1.1` |

零第三方依赖，不需要 CocoaPods / SPM 拉包。

## 3. 装完先验三件事

```bash
git clone https://github.com/tangzzz-fan/SportsHelper.git && cd SportsHelper
xcodegen generate
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

预期：生成工程成功；单测 375 条 + UI 测试 12 条，全部通过。若出现大量失败，先看 `~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh probe` 的模拟器探测结果，别先怀疑代码。

**必须分两次跑**，不要指望一条命令全绿：

```bash
~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh test --project DongKe.xcodeproj --scheme DongKe -only-testing:DongKeCoreTests
~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh test --project DongKe.xcodeproj --scheme DongKe -only-testing:DongKeUITests
```

原因：脚本看到第一条 `Executed N tests` / `Test run with N tests` 就认为「结论已出」，再等 20 秒仍不退出就 SIGTERM。跑完单测后 UI 测试还没开始，就会被这条宽限掐掉。跑单类/单目标时它是对的，跨目标必须分开调用。

另外 `ios-run.sh` 的尾巴会打 `Executed 0 test` + `TEST SUCCEEDED`——XCTest 计数器不认 Swift Testing，单测真实结果看日志里的 `Test run with 442 tests`。UI 测试是 XCTest，看 `Executed 13 tests`。

## 4. 专家团怎么续上

专家团本身跟着账号走，不跟着机器走；但**团队成员的对话上下文不迁移**——换机后是全新的三个角色，它们只知道你这次告诉它们的东西。

1. 新机器装 WorkBuddy，登录同一账号。
2. 左侧「专家」→ 选 `MvpDevExpertTeam`（与旧机同一个专家包）。
3. 首条消息把下面这段整套粘进去，不要只说「继续」：

> 接手动刻（DongKe）项目，仓库已 clone 在本机。先按顺序读：`docs/HANDOFF.md`（本文件）、`docs/FROZEN-BASELINE.md`、`docs/SPEC.md`、`docs/GATE-2-TEST-REPORT.md`、`.workbuddy/memory/2026-10-22.md`。
> 铁律：开发唯一依据是 FROZEN + SPEC，PRD / ARCHITECTURE / UIUX 只作存档，不许再跨角色对账或改写文档。
> 现状：文档已冻结，Gate 2 已放行；197 条测试全绿，构建通过。
> 现在只做一件事：复述你读到的 MVP 范围、三条硬口径（字体零打包 / 占位键 `_generic` / 帧数动态 3 静力 2），然后停下等我放行。不要写代码，不要改文档。

第 4 步是刻意设计的验收：让新团队先复述，确认它读的是文件当前版本而不是旧记忆。旧机上反复出现的返工，全部来自角色凭记忆对账。

## 5. 已定的三条硬口径

不要在新环境重新讨论这三条，改口径等于返工：

| 口径 | 结论 | 位置 |
|---|---|---|
| UI 风格 | **Apple 原生**：NavigationStack / insetGrouped List / TabView / 系统语义色 / SF 字阶；深青绿 `#0E7C66` 只作 tint、选中态、进度环、主按钮 | 2026-10-22 用户裁决，取代 UIUX 的自建视觉体系 |
| UI 出稿工具 | OpenDesign（本机 daemon `127.0.0.1:7456`，项目 `dongke-native`，skill `swiftui-design`）；设计稿只作实施依据，不参与文档对账 | 同上 |
| 字体 | 零打包。`UIAppFonts` 为空，仓库无字体文件；倒计时用系统等宽 + `.monospacedDigit()`；字号与字族只在 `Theme/Typography.swift` 出现；88pt 是全项目唯一自定字号 | SPEC §4 / §8、ARCH §14.4 |
| 占位骨架键名 | `_generic`（不是 catalogId，下划线前缀保住「白名单严格等于 18 个」） | ARCH §12.5 第 1 条 |
| 骨架帧数 | 动态动作恰 3 帧（起始 / 最吃力点 / 回起始），`staticHold: true` 的静力动作恰 2 帧，`_generic` 恰 1 帧 | ARCH §12.5 第 2 条 |

其余冻结项见 `docs/FROZEN-BASELINE.md` 的 12 条决策。

## 6. 目录约定

| 路径 | 说明 |
|---|---|
| `docs/` | 规范与样本。`FROZEN-BASELINE.md`、`SPEC.md` 是上位依据 |
| `docs/specs/` | 本轮 spec。`2026-10-22-figure-and-glass.md` 是素材替换 + 玻璃界面的现行依据 |
| `docs/design/` | 设计稿快照（`<日期>-<页面名>/index.html` + `brief.md` + `shots/`），只作实施依据，不参与文档对账 |
| `.scratch/<feature>/issues/` | 本地 ticket 看板，一票一文件；`README.md` 是索引与当前前沿 |
| `DongKeCore/` | Domain：模型、解析、排程、休息状态机、图示。只 import Foundation |
| `DongKe/DesignSystem/` | 主题令牌与玻璃修饰器（`glassSurface`）；`Icons.swift` 是 SF Symbols 的唯一入口，页面里不得出现 `Image(systemName: "字面量")` |
| `DongKe/` | App 层：Features / Services / Data / App |
| `DongKeCoreTests/` | Swift Testing，纯逻辑，不依赖模拟器 UI |
| `.workbuddy/memory/` | 工作日志，**已纳入 git**，换机随仓库带走 |

## 6.0 导入链路（别人给的计划怎么变成结构化计划）

三种输入形状走同一条链路，代码都在 `DongKeCore/Import/`：

```
任意 JSON / 表格 / 列表 / 散文
        ↓  适配器链（PlanDraftParser：表格 → 行扫描；JSON 走 DraftJSONAdapter）
   PlanDraft（容错中间层：动作名原样留、剂量可缺、每行记出处）
        ↓  实体解析（ExerciseAliasResolver）+ 补默认值
   WorkoutPlan（7 天骨架 + PlanValidator）
        ↓
   校对页（假设逐条列出、未识别动作可标可换）
```

要加一种新格式，只加一个适配器产出 `PlanDraft`，编译器与页面都不用动。要给某个 agent 定契约，就让它输出 `AIPromptBuilder.copyablePrompt(profile:)` 里那份提示词要求的 JSON——直连 AI 与「复制提示词」按钮**共用同一份** system prompt（ARCH §8.3），不再维护第二套模板。

**剂量单位的三种形态都在 `SetTarget` 上**：`reps`（次）、`durationSec`（秒）、`distanceM`（米）。行扫描已经把 `5 公里 / 1.5 公里 / 800 米 / 3km` 解析成 `distanceM`（公里 ×1000 存米）；显示统一走 `SetTarget.doseText`（≥1000 米自动变「5 公里 / 1.5 公里」，否则「800 米」），耗时估算统一走 `estimatedWorkSeconds`（次数 ×3 秒、时长原值、距离每米 0.4 秒）。**新增目标类型时这两处必须一起改**，否则训练页会把它当「次」显示、时长估算按 3 秒算。

### 库外动作的三层处理（22–24）

计划里出现库里没有的动作时，**不拦、不扔、不静默改写**，分三层：

| 层 | 触发 | 结果 | 用户看到 |
|---|---|---|---|
| 猜 | 别名命中但原文带库内覆盖不到的限定词（杠铃 / 箱式 / 保加利亚 / 单腿 …） | 仍按最接近的动作计入 | 橙色「按深蹲计入」，标题保留原文名 |
| 记 | 用户在校对页改过一次 | 写进 `dk.alias.memo`（UserDefaults） | 青色「上次记为深蹲」，下次导入不再问 |
| 存 | 用户点「存为我的动作」 | SwiftData `UserExerciseEntity`，id 与计划里的 `custom_<slug>` 同一个 | 动作库多一个「我的动作」分区，青色「我的动作」徽标 |

关键不变量：`CustomExerciseId.id(for: name)` 是唯一的 slug 生成处，`custom_` 前缀在计划、我的动作、图示兜底三处指的是同一个 id。修它之前先看 `UnknownExerciseTests`。

`ExerciseAliasResolver.aliases` 是**唯一**别名表（行扫描的多动作切分也读它）；不要再另建一份，重复过两次都出过事。

## 6.1 截图自检钩子

调试构建支持用环境变量直达某一屏（仅 `#if DEBUG`，发布构建无此分支）：

```bash
xcrun simctl terminate booted app.dongke.ios
SIMCTL_CHILD_DK_PREVIEW=workout xcrun simctl launch booted app.dongke.ios   # 训练执行
SIMCTL_CHILD_DK_PREVIEW=plan    xcrun simctl launch booted app.dongke.ios   # 计划
SIMCTL_CHILD_DK_PREVIEW=history xcrun simctl launch booted app.dongke.ios   # 记录
SIMCTL_CHILD_DK_PREVIEW=rest    xcrun simctl launch booted app.dongke.ios   # 休息面板
SIMCTL_CHILD_DK_FORCE_LEGACY_GLASS=1 xcrun simctl launch booted app.dongke.ios  # 强制走 iOS 18 玻璃回退分支
SIMCTL_CHILD_DK_SEED_SESSION=1 xcrun simctl launch booted app.dongke.ios       # 写一条训练记录（验持久化）
SIMCTL_CHILD_DK_REQUEST_PROVISIONAL=1 xcrun simctl launch booted app.dongke.ios # 静默授权，验提醒排程
SIMCTL_CHILD_DK_PREVIEW=onboarding SIMCTL_CHILD_DK_ONBOARD_STEP=0..4 xcrun simctl launch booted app.dongke.ios  # 引导各屏
SIMCTL_CHILD_DK_COMPLETE_ONBOARDING=1 xcrun simctl launch booted app.dongke.ios # 用默认值完成引导
SIMCTL_CHILD_DK_RESET_PROFILE=1 xcrun simctl launch booted app.dongke.ios       # 清掉档案，回到未引导
SIMCTL_CHILD_DK_PREVIEW=summary xcrun simctl launch booted app.dongke.ios      # 完成总结（预置 4 组完成 + 1 组降阶）
SIMCTL_CHILD_DK_PREVIEW=library | detail xcrun simctl launch booted app.dongke.ios  # 动作库 / 动作详情
SIMCTL_CHILD_DK_PREVIEW=import SIMCTL_CHILD_DK_IMPORT_SAMPLE=1 xcrun simctl launch booted app.dongke.ios  # 直接看校对页（示例文本只预填，不自动识别）
SIMCTL_CHILD_DK_PREVIEW=import SIMCTL_CHILD_DK_IMPORT_PASTE='{"days":[{"day":"周一"' xcrun simctl launch booted app.dongke.ios  # 预填任意文本（验截断/超量提示）
SIMCTL_CHILD_DK_SEED_USER_EXERCISE=1 xcrun simctl launch booted app.dongke.ios   # 塞一个「我的动作」（农夫行走）
SIMCTL_CHILD_DK_PREVIEW=myexercise SIMCTL_CHILD_DK_SEED_USER_EXERCISE=1 xcrun simctl launch booted app.dongke.ios  # 我的动作详情
xcrun simctl spawn booted defaults write app.dongke.ios dk.alias.memo -dict "保加利亚分腿蹲" "squat"  # 预置别名记忆，验第三层
SIMCTL_CHILD_DK_SEED_AI=1 xcrun simctl launch booted app.dongke.ios   # 预置 AI 接口与假 Key（验已配置态）
SIMCTL_CHILD_DK_SEED_CHECKPOINT=1 xcrun simctl launch booted app.dongke.ios   # 预置一条断点，今日页出「上次训练没做完」
SIMCTL_CHILD_DK_ERASE_ALL=1 xcrun simctl launch booted app.dongke.ios   # 走一遍「清空全部数据」（下次裸启动应回到引导）
SIMCTL_CHILD_DK_PREVIEW=settings SIMCTL_CHILD_DK_SETTINGS_BOTTOM=1 xcrun simctl launch booted app.dongke.ios  # 设置页直接滚到底（关于 / 清空）
xcrun simctl io booted screenshot /tmp/shot.png
```

注意必须先 `terminate`：App 已在运行时 `launch` 不会重启进程，环境变量不生效。

玻璃分支判断是 `#available(iOS 26)`，因此**任何 ≥26 的运行时都走原生分支**；要验证回退观感只能用 `DK_FORCE_LEGACY_GLASS=1`，不要指望装 iOS 26 运行时能覆盖到。

## 6.2 AI 直连（BYOK）

用户自己填 `Base URL + Key`，App 只做「调用 + 解析」，不代管密钥、不自建后端。Key 走 Keychain（`AfterFirstUnlockThisDeviceOnly`），Base URL 与模型名走 UserDefaults。

| 层 | 文件 | 职责 |
|---|---|---|
| Core（可单测，只 import Foundation） | `AI/AIEndpoint` | Base URL 归一化：非 https 直接拒，末尾斜杠不产生双斜杠，已带 `/chat/completions` 不重复拼 |
| | `AI/AIPromptBuilder` | system prompt（内联 schema + 18 个 catalogId + 7 条硬规则）与 user brief（档案） |
| | `AI/ChatRequestBodyBuilder` | 请求体与 `response_format` 三级形态 |
| | `AI/AIResponseMapper` | HTTP 状态 + 正文 → `.content / .degrade / .failure` |
| | `AI/AIPlanInterpreter` | 模型输出 → `ParsedPlanDraft`（复用导入链路，不另开解析器） |
| | `AI/PlanSchemaJSON` | `docs/plan-schema.json` 的压缩副本（唯一真相仍是 docs 那份） |
| App（IO 层） | `Services/AIPlanClient` | **全仓唯一持有 `URLSession` 的类型**；三级降级 + 仅 429/5xx/超时各重试 1 次（退避 2 秒） |
| | `Services/KeychainService` / `AISettingsStore` | Keychain 读写；设置读写与 `isConfigured` 判定 |
| | `Features/Import/AIGenerateCard`、`Features/Settings/AISettingsCard` | 生成入口与配置表单 |

降级顺序固定：`json_schema(strict)` → `json_object` → 不带 `response_format`。判据是 **400 且正文提到 `response_format` / `json_schema` / `not supported`**；其它 400 不当降级信号，直接报错。三级都降完仍失败 → `serverError(400)`，文案引导改用粘贴导入。

验证「唯一网络出口」：`grep -rn "URLSession" --include=*.swift DongKe DongKeCore` 应当只命中 `Services/AIPlanClient.swift`。

改 schema 时同步 `PlanSchemaJSON`：测试守了两件事——`$defs` 恰好 6 个、18 个 catalogId 全部出现在 prompt 与 schema 文本里；drift 会红。

**未做**：401 / 429 / 超时的真实端点 E2E（本机沙箱出网白名单不放行任意外部域名）；Key 的「先验证再保存」也没做——保存不联网是刻意选择，401 时给「去改 Key」入口。

### 内置 Key（临时，上架前必须清）

`DongKeCore/AI/AIDefaults.swift` 从 `Bundle.main` 读 `ai-defaults.json`（由 `.env` 转换而来，**已被 gitignore**），用户没填 Key 时用它。三件事要记住：

1. **这是为「说一句就能用」做的临时通道**，不是长期方案。它让 F10「用户自填 Key」和 AC-18/AC-19 的「缺 Key」分支同时失效——`hasKey` 恒为真。
2. **JSON 文件随包分发，可以被 dump。** 上架前必须把 `ai-defaults.json` 从 bundle 里摘掉（或让 Key 字段为空），否则等于把 Key 送出去。
3. 判定链路：`AISettingsStore.usesBuiltInKey` = 用户没填 且 包内有 Key。清掉包内 Key 后这条自动变假，不用改代码。

**上架检查项：`sh ipa 解包后确认 Payload/DongKe.app/ai-defaults.json 不存在或 apiKey 为空`。**

## 6.3 训练执行的三条不变量

| 不变量 | 位置 | 破坏后的表现 |
|---|---|---|
| 每完成 / 降阶 / 跳过一组，都要同时写 `SetLogEntity` 与 `dk.workout.checkpoint` | `WorkoutSession.appendLog` → `saveCheckpoint` | 历史里降阶率恒 0；杀进程后断点丢一组 |
| 断点只在 **30 分钟内**、且 `stepIndex < totalSteps` 时可续；训练正常结束必须 `clear()` | `WorkoutResumePolicy.canResume` / `saveCheckpoint` | 昨天没做完的计划第二天还弹「继续训练」 |
| 休息的 `endAt` 是绝对时间；通知与触觉都由状态机的 effects 驱动，不由 View 自己计时 | `RestTimerStateMachine` → `syncRestNotification` → `Haptics.restFinished` | 锁屏回来倒计时跳变、或归零没声音 |

休息通知标识固定 `dk.rest.<sessionId>`（`RestNotificationBuilder.prefix`），排程前先清同前缀，绝不碰 `dk.plan.`。通知负载：训练提醒带 `dk.weekday`，休息通知带 `dk.dayIndex`，点击统一由 `NotificationRouter` 解成 `WorkoutDeepLink` 交给 AppShell。

**AC-10 / AC-14 的落地形态**（2026-10-23）：训练页在剂量下方直接显示动作库前两条 `cues`（自定义动作没有 cues 就整块不显示，不占位）；「这组做不动」先弹 `confirmationDialog` 问「减一半次数 / 减一半时间」（按 `target.type` 切文案），确认后才 `downgradeSet()`——只改本组、记降阶，后面照原计划。**不要再改回"点了就减半"**，AC-14 要求"点并选"。

## 6.4 清空全部数据

入口在设置页底部，走 `DataResetService.clearAll`：删五张表（SetLog / Session / Plan / Profile / UserExercise）→ 清 `dk.` 前缀的全部 UserDefaults → 删 Keychain 里的 AI Key → 取消 `dk.plan.` 与 `dk.rest.` 待触发通知。完成后 `AppShell.handleEraseAll` 重新 load 各 store 并弹回引导。

验证方式（模拟器可复现）：`DK_COMPLETE_ONBOARDING=1` 建数据 → 杀进程 → `DK_ERASE_ALL=1` 跑一次 → 杀进程 → 裸启动应回到引导第一屏。注意 `simctl` 有两台 booted 模拟器时一律**写 UDID**，`booted` 会解析到另一台。

## 6.5 文件拆分（2026-10-23）

> 2026-10-25 上限从 300 改到 **500**（ARCHITECTURE §4.3-1）。已经拆开的文件**不回并**——它们是按职责边界切的，不是为凑行数切的；回并只会把刚理清的主职责搅回去。新代码按 500 看。

SPEC §4「单文件 ≤300 行」已全量满足。拆分方式分两种，**都是纯移动、无行为改动**：

| 类型 | 做法 | 例子 |
|---|---|---|
| 多个并列视图 | 按类型边界切成独立文件 | `ExerciseLibraryView` → `UserExerciseDetailView` / `ExerciseDetailView`；`ImportView` → `PlanReviewView` / `PlanEditSheet`；`TodayView` → `TodayView+Cards` / `ProgressBar` |
| 单个大类型 | 用 `extension` 拆到 `+Flow` / `+State` / `+Dose` / `+Text` / `+Aliases` 等文件 | `WorkoutSession`、`DraftLineScanner`、`OnboardingView`、`PlanGenerator`（目录数据抽成 `PlanCatalog`） |

**代价（必须知道）**：extension 分布在多个文件时，`private` 成员互不可见，所以被拆类型的部分成员从 `private` 放宽成了模块内可见（如 `TodayView.store`、`OnboardingView.draft/step`、`WorkoutSession.logs/rest`）。这是模块内部可见性，不对外暴露；但**别再往这些类型上加新的公开面**，要加就加在新的 extension 文件里。

**仍欠**：无。字号已在 §6.8 收口。

## 6.8 字号与 Dynamic Type（2026-10-23）

全仓 `.font(.system(size:))` 只有一处，就在 `DongKe/DesignSystem/Typography.swift` 的 `Typography.timer`（88pt，design-tokens 允许的唯一自定尺寸）。其余一律走 `Typography` 的语义常量，底层全是系统文本样式，所以自动跟随 Dynamic Type。

| 令牌 | 系统样式 | 用在哪 |
|---|---|---|
| `pageTitle` | largeTitle + bold | 今日 / 计划 / 记录三个页标题 |
| `actionTitle` | title + semibold | 总结页主结论、引导问句 |
| `detailTitle` | title2 + semibold | 卡内大字（动作名、百分比）、校对页标题 |
| `buttonLabel` | body + semibold | 按钮文字、导航栏动作 |
| `rowTitle` / `cardTitle` | callout + medium / semibold | 设置行、列表行 / 卡片标题 |
| `body` / `secondary` / `meta` | body / subheadline / footnote | 正文 / 辅助 / 元数据 |
| `micro` / `capsLabel` | caption / caption2 + semibold | 徽标、英文小标签 |
| `monoInput` | subheadline + monospaced | 粘贴框、接口输入框 |
| `bigNumber` | largeTitle + semibold + monospaced | 完成率、连续天数等主数字 |
| `timer` | 88pt + light + monospaced | 休息倒计时（唯一自定尺寸） |

**偏离一处，已决定并记录**：`typography.style.pageTitle` 在 token 里写 `.title2`（22pt），但已验收的三个页标题一直是 34pt bold，降到 22 会让页面失去标题层级。实现保留 largeTitle（34pt），换字号体系时**不要"按 token 改小"**，否则三个页标题会一起缩水。

**Dynamic Type 配套改动**：三个页签（今日 / 计划 / 记录）都套了 `ScrollView` + `contentMargins(.bottom, 96)`，否则 AX 字号下内容被底部页签岛永久压住、滚不到；总结页改成 `GeometryReader + ScrollView`（默认字号下仍垂直居中，超出可滚）；训练页组数行合并成单个 `Text` 插值并加 `fixedSize(horizontal: false, vertical: true)`，`结束` 按钮从固定 52pt 宽改成 `minWidth` + `fixedSize`（AX3 下原本被压成省略号）；休息倒计时补 `accessibilityLabel("休息剩余")` + 按 10 秒取整的 `accessibilityValue`，并封顶 `dynamicTypeSize(...accessibility2)`。

AX3（`xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`）已逐页截图核对：训练页三项核心信息、总结页圆环与统计、三个页签的行文字均无截断、无省略号。

## 6.9 完成口径（2026-10-23）

「今天算不算练过」只有一个判据：`SessionRecordSummary.isCompleted`（`completedSets >= plannedSets`；降阶计入完成、跳过不计）。连续天数与「本周 N/3」都按**完成过的天**去重统计——做一半既不加连续，也不占周目标。

| 位置 | 唯一实现 | 说明 |
|---|---|---|
| 比率与截断 | `HistoryStats.rate(_:of:)` | 分母 ≤0 返回 nil，结果夹在 0…1；`SessionSummary`（记录页）与 `SessionRecap`（总结页）都调它，页面不再自己除 |
| 连续天数 | `HistoryStats.streak` | 只认完成日；今天还没完成时从昨天回溯 |
| 本周完成 | `HistoryStats.completedDaysThisWeek` | 只数本周内的完成日；同一天练两次算一天 |

`CompletionRateCalculator` 已删除：它和 `HistoryStats` 是两套口径（阈值 0.8 vs 全部完成），且 App 里零调用，是死代码。AC-17 要的是「完成当天全部组」，以 SPEC 为准。**不要再引入第二套 streak / 周计数**——别名表两份已经出过一次事。

## 6.10 解析与拆解的边界用例（2026-10-23）

三个 mock 用例文件按管线分段，输入全是手写字符串常量，不读磁盘、不联网：

| 文件 | 覆盖 |
|---|---|
| `LineScanEdgeCaseTests` | 全角数字、中文数字、小数休息、`12次×4组`、`3x12`、每侧、距离/时长、重量、一行多动作、超级组、Markdown 勾选框/列表/分隔线、注意事项、标题、CRLF |
| `JSONPayloadEdgeCaseTests` | 围栏 + 前后散文、顶层数组、weeks 嵌套、尾随逗号、字符串数字、区间次数、null reps、中文字段名、缺 restSec、3 天 vs 7 天、空容器、全角引号/冒号、BOM、组数 0 |
| `PlanStructureEdgeCaseTests` | 五种星期写法、没写星期按顺序补、第八天丢弃、循环区块、静力默认 30 秒、`custom_` slug、我的动作补剂量、默认 cautions、daysPerWeek、估算时长、itemId、默认休息 |

这批用例顺带修掉五个真问题（都是「静默算错」而不是报错）：

1. 全角数字 `４组×１２次` 读不出剂量 → 自由文本入口先做 `TextNormalization.halfWidthDigits`。
2. 中文数字 `四组十二次` 读不出 → 同一入口 `chineseNumerals`，**只转换紧跟「组/轮/次/秒/分钟/分」的数字**，避免把动作名里的数字改坏。
3. `休息1.5分钟` 被算成 **1 秒** → 组间休息与时长正则改吃小数，分钟乘 60 后四舍五入。
4. `- [ ] 深蹲 3×12` 被 `[ ]` 骗进 JSON 分支、报「结构不符」 → 提取器只在数组里真有对象时才当 JSON。
5. 代码围栏 / 前后带散文的**通用 JSON** 解析不了（提取到的正文没被复用）→ `PlanImportService` 三档解码统一用提取结果；全角引号、全角冒号逗号只在 JSON 解析失败后做一次「引号感知」修复，`usable()` 先试原样解析。

**已知边界（测试里明写为当前行为）**：只有动作名、剂量全无、别名也查不到的行会被整行丢掉（`周一 壶铃摆动` → 无计划）。这与「我的动作不参与行检测」是同一处遗留。

## 6.11 不完整与过量输入（2026-10-23）

粘贴内容只有两种坏法：**没粘完**和**粘太多**。判据放在 Import 链路最外层，先挡再解析。

| 输入 | 规则 | 用户看到 |
|---|---|---|
| 超过 64KB | 直接拒绝 | 「内容超过 64KB，请只粘贴计划本身」 |
| 超过 500 行（只按第一周计） | 直接拒绝 | 「内容太多（超过 500 行），先只粘贴一周的计划」 |
| 像 JSON 但括号/围栏没闭合 | 不落到自由文本 | 「像是 JSON，但没粘完整」 |
| 多周计划（`第 2 周` / `Week 2` 起） | 只保留第 1 周，后面整段丢弃 | 假设里写「只保留第 1 周」 |
| `Day 8` / `第 8 天` 等超出一周的日子 | 当额外一天解析，排不下就丢 | 假设里写「多出的 N 个动作已略去」 |
| 同一天里完全相同的动作 | 只留第一次 | 假设里写「N 个动作完全重复」 |
| 单日超过 20 个动作 | 校验报错 | 「动作过多，先只保留一周的计划」 |
| 只有标题 / 只有注意事项 / 空内容 | 不生成计划 | 「未能从这段内容里识别出动作」 |

判定细节：

- 行数护栏按**第一周之前的行**算：600 行的 6 周计划不会被误杀（`PlanImportService` 与 `DraftLineScanner` 共用 `weekNumber`）。
- 周标题只在整行就是 `第 N 周` / `Week N` 时才算；`增肌计划 第一周` 仍是标题。只有粘贴从「第 2 周」开始时，才把它当第一周保留。
- 重复折叠的判据是「归一化动作名 + catalogId + 组数 + 次数 + 类型 + 每侧」，**剂量不同不算重复**，`哑铃划船 3×12` 与 `弹力带划船 3×12` 也不会被合并。
- 截断判定：以 `{`、`[{` 开头，或以 ``` 开头且正文含 `{`，或正文含 `"days"` / `schemaVersion`。围栏里是纯文本时仍走自由文本。
- 这些规则都锁在 `IncompleteImportTests` / `OversizedImportTests` 里，stub 构造器在 `ImportStubs.swift`（`day` / `week` / `repeated` / `exercises(count:)` / `genericJSON`）。

## 6.12 动作名词与单位名词（2026-10-23）

`ExerciseAliasResolver.aliases` 仍是唯一别名表。这次把它当「名词 → catalogId」的字典来测，而不是只测几条样例。

| 层 | 规则 | 位置 |
|---|---|---|
| 同义名 | 每个内置动作 ≥3 个叫法（口语 / 器械 / 英文），自己的名字必须认得出自己 | `ExerciseNounTests` |
| 变式 | 带限定词（杠铃 / 箱式 / 保加利亚 / 跪姿 / 钻石 / 坐姿 / 俯身 / 反向 / 跳 / 机…）命中时**不否决**，只打橙标 | `modifiers` |
| 易混 | `靠墙深蹲 → 靠墙静蹲`、`对侧支撑 → 鸟狗`、`侧身平板 / 侧平板 → 侧平板`；`仰卧起坐` 不并入 `卷腹`；`划船机` 带「机」标 | `ConfusableNounTests` |
| 库外 | 卧推 / 硬拉 / 腿举 / 引体向上 / 二头弯举 / 侧平举 / 臀推…一律保持 custom，不硬塞 | 同上 |
| 繁体 | `啞鈴划船 / 靠牆靜蹲 / 側平板支撐 / 開合跳 / 俄羅斯轉體 / 捲腹 / 俯臥撐` 先归一再匹配（展示也归一） | `TextNormalization.traditionalMap` |
| 单位 | 次数：次 / 下 / `个`（仅当同一行写了组数）；时长：秒 / s / S / 分钟 / min；距离：米 / 公里 / km | `DraftLineScanner+Dose` |
| 星期 | 周 / 星期 / 礼拜 + 一~日/天；Mon / Monday / Tues / Thurs…；Day N；第 N 天 | `DraftLineScanner+Text` |

两条不变量由测试守着：**别名表自洽**（每条别名命中自己声明的 id、没有同名两投）与**覆盖**（18 个 id 各 ≥3 个叫法、别名 id 全部存在于动作库）。

**坑一**：`个` 不能无条件当次数——「今天 5 个动作」是标题，不是一组 5 个；所以只在同一行已经有「组」时才吃 `N 个`。
**坑二**：繁体只收了动作名与单位会用到的三十来个字，不是完整 OpenCC；没收录的字会落回 custom，不会乱配。
**坑三**：`修饰词否决` 的顺序是先精确匹配、再按长度取包含匹配，所以新增短别名（`下蹲`、`旋体`）不会抢走长别名（`靠墙深蹲`、`俄罗斯旋体`）。

## 6.6 UI 测试（2026-10-23）

`DongKeUITests` 是 XCTest 目标（Swift Testing 不支持 XCUIApplication），十三条用例覆盖四条主链路：引导五步 / 导入粘贴→识别→校对→保存（含「截断 JSON 提示没粘完整」）/ 训练→休息→跳过→总结（含要点与「做不动」三选）/ 设置开关（提醒 + 语音）与清空，另有一条在无障碍字号下断言训练页四个控件可点。

| 机制 | 说明 |
|---|---|
| 标识符 | `Shared/A11yIdentifiers.swift` 的 `A11y` 同时编进 App 与 UI 测试，改一边另一边编译期就报错，避免字符串漂移 |
| 隔离 | `DK_UI_TEST=1` 让 `ModelContainer` 走内存存储，并在 `DongKeApp.init` 清掉全部 `dk.` UserDefaults ⇒ 每次启动都是干净的零数据 |
| 预置 | `DK_COMPLETE_ONBOARDING=1` 在 init 里直接写档案（不再是 `.task` 里补写），所以首帧就落在今日页，不会闪一下引导 |
| 点击 | 用例一律用 `tap(_:)` 助手，它按元素**中心坐标**点击。`element.tap()` 在带 `overlay` 的按钮上会做「避开遮挡」的坐标调整，实测会落到空白处（`today.start` 因此永远点不动），不要换回去 |
| 等待 | 转场后先等元素消失（`waitUntilGone`）再点下一个，否则休息面板的淡出层会吃掉下一次点击 |

## 6.7 引导不再是全屏弹层（2026-10-23）

原来的 `AppShell` 同时挂了两个 `fullScreenCover`（引导 + 训练），SwiftUI 只认先注册的那个，**训练页永远弹不出来**（点「开始训练」毫无反应）。现在引导挪到 `RootView`：`profileStore.hasOnboarded == false` 就直接渲染 `OnboardingView`，否则渲染 `AppShell`。清空数据后 `profileStore.load()` 变空，根视图自动切回引导，不需要额外的状态位。

`AppShell` 里因此只剩一个 `fullScreenCover(item: $session)`。**别再加第二个全屏弹层到这个视图上。**

## 6.13 AI 真实链路实测（2026-10-24）

`.env.example` 里曾放真实 Key，已拆成 `.env`（600，gitignore）+ 占位示例。变量统一为 `DEEPSEEK_API_KEY` / `DEEPSEEK_BASE_URL` / `DEEPSEEK_MODEL`，模型 `deepseek-flash`。

两条复现路径：

- `scripts/ai-smoke.sh "重点练手臂"`：`swiftc` 编译 `DongKeCore` + `Tools/AISmoke`，直接跑 `AIPromptBuilder → ChatRequestBodyBuilder → AIResponseMapper → AIPlanInterpreter`，不依赖模拟器。
- `scripts/ai-sim.sh [UDID]`：把 `.env` 经 `SIMCTL_CHILD_DK_AI_*` 注入 App（仅 DEBUG），`DK_AI_AUTOGEN=1` 自动触发一次生成，停在核对页。

实测（deepseek-flash）：

- `json_schema` 返回 400 `This response_format type is unavailable now`，命中 `AIResponseMapper` 的降级条件 → `json_object` 成功；三级降级顺序不用改。
- 3 天计划 23–29 秒、17–23KB；App 内同样在 60 秒超时内完成。
- 首版一天 9–12 个动作、3 天 57 组，30 分钟装不下 → `AIPromptBuilder.userBrief` 增加每日上限：动作 ≤ `sessionMinutes/5`（30 分钟 = 6）、组数 ≤ `sessionMinutes/2`（= 15），并要求估算时长落在 ±15%。复测 18 动作 / 45 组。
- 截图：`docs/design/2026-10-22-liquid-glass/shots/t36-ai-deepseek-live.png`。

**注意**：`.env` 不进仓；`DK_AI_*` 只在 DEBUG 生效，且会把 Key 写进模拟器钥匙串。换 Key 或换机器时去设置页「清除 Key」。

## 6.14 一句话意图 PlanBrief（2026-10-24）

`PlanBrief` 是「用户说的一句话」与「档案」之间的中间层：解析器只产出**可选覆盖**，没说的字段一律 `nil`；`resolved(against:)` 才把 `nil` 回落档案，并算出本次的 `maxExercises` / `maxSets`。

- 输入归一：`TextNormalization` 增补了 `天`、`小时` 两个单位，以及 `週/練/時/鐘/個/兩/傷` 七个繁体字。
- 星期解析是独立的，不复用 `DraftLineScanner.weekday(in:)`：后者只取第一个，而且会把「每周三天」读成周三。
- 频率与星期的歧义靠「先剔频率再解析星期」解决：`每/一 + 周 + 数字 + 天/次/练` 视为频率；`周一三五练` 是一串具体星期，不能剔。「每天 / 天天」也要先剔，否则会被读成两个周日。
- `每周三天` + `周一三五` 同时出现时，保留星期、丢弃天数；`resolved` 以星期为准。
- 「隔天」不硬换算成 3 天或 4 天，写进 `unparsed` 让确认页选。
- 测试 36 条（`PlanBriefParserTests` + `PlanBriefResolutionTests`）。

## 6.15 一句话生成：确认页与接线（2026-10-24）

流程现在是：句子 → `PlanBriefParser` → 「我理解为」确认页 → 可编辑 brief → `AIPromptBuilder` → `AIPlanClient`。

- `AIGenerateCard` 的句子输入绑定在 `ImportView` 的 `aiSentence`，所以「复制提示词」与生成用的是同一份 brief，不再各说一套。
- 确认页可改星期 / 时长 / 器械 / 目标；重点与避开只读；伤病与避开收进首屏约束卡；原话回显在标题下。
- 嵌套 sheet 里 `.sheet(isPresented:) + 可选值` 会偶发不弹出，**必须用 `.sheet(item:)`**。
- 底栏走 `safeAreaInset`；AX 字号下主/次按钮改成纵向堆叠，避免文字换行把底栏撑到半屏。
- 测试钩子：`DK_BRIEF_SAMPLE` 预填句子、`DK_BRIEF_CONFIRM=1` 直接开确认页、`DK_AI_FAKE=1` 跳过网络返回档案生成的计划。
- 测试 375 / UI 12；截图 `t37-brief-confirm.png`。

**关于 AX3**：确认页没有强制 AX3，`BriefConfirmView` 只是在系统字号本身是无障碍档时切换底栏布局。之前看到 AX3 是因为截图命令手动设了 `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`；现已复位 `large`，并删掉本次的 AX3 截图。以后不再用 AX3 做常规验收。

## 6.16 复核 02–04：门禁与口径的修正（2026-10-24）

对 `524286a..f22843f`（三个提交）做了一次双轴复核（Standards / Spec），查出并修掉六处：

1. **`BriefConfirmView` 325 行**撞 §4.3 规则 1，门禁第 6 条非空。拆成 `BriefConfirmView.swift`（状态、`editedBrief`、`sourceText`）与 `BriefConfirmView+Sections.swift`（版式）。约定：跨文件扩展取用不到的成员不要写 `private`，跟 `TodayView+Cards` 一致。
2. **每日训练量上限有两套公式**，且 30 分钟时互斥：`maxExercises = minutes/5 = 6`、`maxSets = minutes/2 = 15`，而 6 个动作各 3 组就是 18 组。现在只有 `EffectivePlanBrief` 一处：先算 `maxSets`，再取 `maxExercises = maxSets/3`（夹 2…8）。30 分钟 = 5 个动作 / 15 组；20 分钟 = 3 / 10；60 分钟 = 8 / 30。`AIPromptBuilder` 不再自己算。
3. **`userBrief` 曾有两份实现**（`extraNote` 版与 `brief` 版）。只留 `brief` 版，`extraNote` 是 `PlanBrief(sentence:)` 的薄包装——注意这改了文案：`补充要求：X` 现在写作 `本次按用户原话生成` + `用户原话：X`。
4. **`AIPlanGenerating` 的两个便捷重载**默认 `memory: .empty, exercises: .empty`，等于把 04 刚修的「AI 路径无视别名记忆」重新打开，且零调用方。整段删除，协议只留全参版本。
5. **确认页的来源标签**原本读 `brief.overriddenFields`（解析结果），用户在页面上改完不重算，会把改过的值标成「沿用档案」。现在直接与档案比：星期 / 时长 / 器械 / 目标与档案一致才标「沿用档案」。
6. **`isVague` 只有测试在读**。确认页标题下加一句「没听出具体安排，下面按你的档案兜底，可以直接改」，让它真的被消费。

顺带收口：确认页按钮改走 `Typography.buttonLabel` / `Typography.secondary`（原来硬写 `.subheadline.weight(.semibold)` / `.footnote.weight(.medium)`，同屏三档字重且绕开 token），去掉 `lineLimit(1)`，「共 N 天」「N 分钟」补 `monospacedDigit`。

**门禁本身也修了两条**（已回写 `ARCHITECTURE.md` §4.3）：`systemName:` 那条会连 `Image(systemName: Icons.x)` 一起拦，永远非空等于失效，改为只查字面量；`UIPasteboard` 那条连写剪贴板也拦，但「复制提示词」没有替代 API，改为只拦读取（非 `= ` 赋值）。

**测试**：单测 375 → 376（新增一条 5…120 分钟全档位 `maxExercises × 3 ≤ maxSets` 不变量；两条旧断言随新公式调整），UI 12 条。

## 6.17 AI 传输层抽出 Core（2026-10-24）

HTTP 从 App 服务里挪进了 `DongKeCore/AI/AITransport.swift`：

```swift
let transport = AITransport.live()          // 或 AITransport(sender: { … })
let request = AITransport.Request(url:key:model:messages:)
let result = try await transport.generate(request)   // result.text / result.mode
```

- `sender: @Sendable (URLRequest) async throws -> Response` 是唯一注入点，`Response` 只带 `status` 与 `body`——测试不用拼 `HTTPURLResponse`，也不需要 `URLProtocol` 的全局注册表。
- `sleep` 同样可注入：重试退避是 2 秒，测试传 `.milliseconds(1)` 并记录调用次数，用来区分「重试了」和「没重试」。
- `AIPlanClient` 现在只剩三件事：读设置、组请求、把 `result.text` 交给 `AIPlanInterpreter`（带 `memory` / `exercises`）。`makeSession()` 挪到 `AITransport.makeSession()`，15s / 60s 超时与 ephemeral 配置不变。
- `Tools/AISmoke` 改吃同一个 `AITransport`，它自己那份降级环删掉了；顺带修掉那里「`interpret` 不传 memory / exercises」的隐患。

**已知边界**：`json_schema` 被拒后的降级不是无损的——DeepSeek 上 `json_object` 档不保证结构，仍由 `PlanValidator` 与校对页兜底。真实端点复测：400 降级 → 200，20.4 秒，2 天 14 个动作 33 组，落在新的 7 个动作 / 22 组上限内。

## 6.18 训练播报（2026-10-24）

三段式，判断全在 Core，App 只剩 AVFoundation 粘合：

| 层 | 文件 | 职责 |
|---|---|---|
| 文案 | `DongKeCore/Workout/WorkoutAnnouncement.swift`、`+Builder` | `WorkoutPlan` + `FlowStep` → 一句 ≤40 字的中文 |
| 闸门 | `DongKeCore/Ports/SpeechAnnouncing.swift`、`Workout/SpeechCueCoordinator.swift` | 开关 / 前台 / VoiceOver 三条件；不可播时立刻停 |
| 出声 | `DongKe/Services/SystemSpeechAnnouncer.swift` | `AVSpeechSynthesizer`（zh-CN，rate 0.5）+ `AVAudioSession .ambient` |

- **闸门放 Core 的理由**：「什么时候不该说话」是产品规则，不该埋在 App 里靠手测。`SpeechCuePolicy` 三个布尔，配假 speaker 就能把让路、打断、恢复全测了。
- `.ambient` + `.mixWithOthers`：尊重静音键（图书馆里不会突然出声），代价是不 duck 音乐。
- 念完 / 取消时 `setActive(false, options: .notifyOthersOnDeactivation)`，不长期占着音频会话。
- 开关在设置页「语音提示」，默认关，键 `dk.voice.enabled`；UI 测试 `testSettingsVoiceTogglePersists` 验持久化。
- 文案上限 40 字：超长先丢「下一个」，再丢「共 N 组」，动作名与剂量最后才动——别在 08 里改成按字数硬截。

**还没接的**：无——09 已把触发接进 `WorkoutSession`。剩下 `10 真机验收`。

## 6.19 播报挂进训练流程（2026-10-24）

```swift
session.voice = WorkoutVoiceSession(plan:dayIndex:coordinator:)   // WorkoutView.onAppear
voice.start() / stepChanged(to:) / restStarted(seconds:nextBlockTitle:) / restTick(secondsLeft:) / restFinished(nextStepIndex:) / finished(completedSets:)
```

挂钩点全在 `WorkoutSession` 的四个方法里，不在视图：`advance()`、`startRest()`、`refresh()`、`finish()`。这样按钮、通知深链、断点续练三条入口都覆盖到；挂 `onChange` 会漏掉通知触发的那两条。

- 倒数只在 `.running` 时 tick，靠 `lastCountdown` 去重（0.25s 一轮不会重复念「3」）；`restStarted` 重置，+15 秒后重新从 3 报。
- 跳过组走 `advance(silent: true)`；完成后 `finished()` 会把会话置为不再活跃，后续 step 不再出声。
- 总结页静音靠 `workoutBody` 的 `onDisappear`；`showsSummary` 时 `onAppear` 直接不启动。

**必须记住的坑**：`onAppear` 时 `UIApplication.shared.applicationState` **还不是 `.active`**，闸门会把第一句吞掉（第一次端到端就是这样零日志）。`VoiceService.activeCoordinator()` 现在显式按 `isForeground: true` 起步，之后交给 `scenePhase` 纠正。

**端到端自检**（假 speaker 写文件，不碰真音频）：

```bash
SIMCTL_CHILD_DK_COMPLETE_ONBOARDING=1 SIMCTL_CHILD_DK_PREVIEW=workout \
SIMCTL_CHILD_DK_VOICE_ENABLED=1 SIMCTL_CHILD_DK_VOICE_FAKE=1 \
xcrun simctl launch <UDID> app.dongke.ios
cat "$(xcrun simctl get_app_container <UDID> app.dongke.ios data)/tmp/dk-voice.log"
```

预期看到 `开始训练，…` 与 `第 1 组，共 3 组，俯卧撑，10 次`。`DK_VOICE_FAKE` 只替换 speaker，闸门与文案走真实代码。

## 6.20 语音输入：说一句填进输入框（2026-10-24）

```swift
SpeechTranscribing（Core 协议）
  → SystemSpeechTranscriber（App：SFSpeechRecognizer zh-CN + AVAudioEngine）
  → VoiceInputMachine（Core，@Observable，状态机 + 60 秒 / 200 字上限）
  → VoiceInputBar（麦克风按钮，挂在 AIGenerateCard 输入框下面）
```

- **两套权限折成五态**：`SpeechAuthorization` 把「语音识别」与「麦克风」并成一个枚举（`.speechDenied` / `.microphoneDenied` / `.restricted` / `.notDetermined` / `.authorized`）。文案只在 Core 写一次；`opensSettings` 只有权限类为真——「没听到」和「中断」不该把人送去设置页瞎点。
- **离线优先，联网先问**：`supportsOnDeviceRecognition` 为真时强制 `requiresOnDeviceRecognition = true`；为假时进 `.awaitingOnlineConsent`，说清「音频由 Apple 处理，本 App 不留录音」，同意才走在线。同意记在 `dk.voice.onlineConsent`，同意过就不再问第二次。
- **离线包缺失只有运行时才知道**：`supportsOnDeviceRecognition` 只是能力位，中文离线模型没下载时 `start` 会抛 `onDeviceUnavailable`。机器捕获后同样转成询问；已同意过的直接改走在线，不打断。
- **60 秒 / 200 字**：`tick()` 由视图每 250ms 调一次，到点自动收尾并保留已识别文本；超过 200 字时置 `didHitLengthLimit`，`capHint` 换成「已到上限」。标记跟着最新结果走——识别器自己修正回短句时提示要消失。
- **不打断音乐**：录音用 `.record` + `.mixWithOthers`，结束时 `setActive(false, options: .notifyOthersOnDeactivation)`。

**必须记住的坑**：`SFSpeechRecognizer` 的 partial 是**全量替换**，不是增量追加。写 `+=` 会得到「想在家想在家增肌」。

**测法**：

| 层 | 手段 |
|---|---|
| 状态机 | `FakeSpeechTranscriber` + `VoiceTestClock`（42 条）：授权五态、部分结果、超时、空结果、超长截断、在线同意、运行时降级、重复点按 |
| UI | `DK_VOICE_TRANSCRIPT` 注入一句话（3 条）：回填、权限拒绝给「去设置」、离线缺失先问再回填 |

`DK_VOICE_STUB` 可取 `denySpeech` / `denyMic` / `restricted` / `onDeviceMissing` / `empty` / `stall`。系统转写器的错误映射只认两件事：`wasOnDevice` 与 `kAFAssistantErrorDomain` / `kLSRErrorDomain` 的 1101 / 1107。

**还没接的**：真机上的中文离线识别、蓝牙耳机拾音、来电打断——归 10 验收清单。

## 6.21 测试范围：什么时候不用跑 UI 测试（2026-10-24）

UI 测试要起模拟器、装 App、点按钮，一轮 16 条约 6 分钟；只改 `DongKeCore` 的解析规则却陪跑一遍，纯属浪费。**默认不跑，要跑显式加 `--with-ui`**。判据仍然落在一条上：**这次改动会不会让「用户点得到的东西」变样**。

```bash
scripts/test-scope.sh              # 只看判定
scripts/test-scope.sh --run        # 跑单测（UI 不跑）
scripts/test-scope.sh --with-ui    # 单测 + UI，约 6 分钟
scripts/test-scope.sh --base HEAD~3
```

| 判定的 scope | 触发路径 | `--run` 跑什么 | `--with-ui` 追加 |
|---|---|---|---|
| `ui` | `DongKe/`、`Shared/`、`DongKeUITests/`、`project.yml`、`DongKe.xcodeproj/` | 单测 | + UI 16 条 |
| `core` | `DongKeCore/`、`DongKeCoreTests/`、`Tools/`，以及 `scripts/` 这类散件 | 单测 | 不追加 |
| `none` | `docs/`、`.scratch/`、`*.md` | 都不跑，仍要过 §4.3 门禁 | 不追加 |

判定为 `ui` 时脚本会打印 `ui-triggers:` 列出触发文件——**看到它就知道该不该补一次 UI**。建议在这些节点跑：

- 提 PR / 提交前，改过视图、入口、设计系统或 `project.yml`
- 改了 `contentShape`、`buttonStyle`、命中区这类「点得到点不到」的东西（见 §6.22）
- 改了播报、语音输入的可见行为（UI 里有 `DK_VOICE_*` 注入钩子）
- 一次没跑过、要上真机前

几个刻意的取舍：

- **`DongKe/Services` 算 ui**。`AIPlanClient`、`VoiceService`、`SystemSpeechTranscriber` 这些是 App 层，改动会改用户看到的行为（401 文案、播报有没有声、麦克风有没有反应），而它们没有独立单测。宁可多跑一次。
- **`DongKeCore` 算 core**。SPEC §10 只要求「UI 只测三条主链路」，Core 的行为变化由 487 条单测兜。真怕漏，就手动加 `--with-ui`——脚本给的是默认档，不是禁令。
- **`DongKeCore` 改**也可能动文案（例如 `VoiceInputCopy`），但文案不靠 UI 测试验，靠 `#expect(failure.message.contains("麦克风"))` 这类断言。
- **`none` 不等于免检**。门禁 grep、`xcodegen generate` 后工程是否干净，一样要跑。

跑之前记得：`ios-run.sh` 会因「结论已出但进程不退场」把 UI 套件掐掉——Swift Testing 的 `Test run with N tests passed` 先出现，20 秒后它就杀进程，而这时 UI 才启动。`test-scope.sh --run` 已绕开这个坑（直接 `xcodebuild` + 日志判定 + `perl alarm` 上界）；手工跑时**不要用 `ios-run.sh` 跑 UI 套件**，直接在命令行 `xcodebuild ... -only-testing:DongKeUITests test`。

## 6.22 按钮命中区：字上能点，字外点不动（2026-10-24）

现象：休息日的「提前练一次」只有点到文字才进得去，点按钮左右两侧的空白没反应。

根因在 SwiftUI 的命中测试规则——**`Text` 的可点区域就是字形本身**。`frame(maxWidth: .infinity)` 只改布局（让文字居中、让父容器知道要撑满），**不会扩大命中区**；`background` 同理，画得出但点不到。按钮看着有 334×52，实际能接住点击的只有中间那块字。

修法：`.contentShape(Rectangle())`。它不改外观，只告诉命中测试「整块都算我」。

- **统一收口在 `PressableGlassStyle`**（`DongKe/DesignSystem/GlassSurface.swift`）：21 处共用按钮样式的地方一次修好。
- 另有 9 处硬编码按钮（`TodayView` 设置与提醒、`WorkoutView` 关闭与结束、`OnboardingControls` ±、`BriefConfirmView+Sections` 胶囊与次按钮、`ImportView` 手动添加、`OnboardingView` 跳过）逐个补 `.contentShape`。

回头检查同类问题的三条经验：

1. **不要按视图结构扫遮挡**。`allElementsBoundByIndex` 会把按钮里的 `Text`、祖先容器都算成「压在上面」，误报一堆。
2. **直接量命中区**。`element.frame` 打印出来对比按钮视觉尺寸，差一大截就是没加 `contentShape`。
3. **UI 测试断言行为，不断言结构**。`DongKeRestDayUITests` 只留两条：点文字能进、点下缘也能进。别写「没有任何元素与按钮框相交」。

新加的按钮一律走 `PressableGlassStyle`，别直接用 `.buttonStyle(.plain)` 配 `Text` + `frame`。

## 6.23 播报文案与训练计划对齐（2026-10-24）

播报是系统 TTS 实时拼字，没有预录音频（唯一出声点 `DongKe/Services/SystemSpeechAnnouncer.swift`）。之前的文案与计划字段对不上，改了四处口径：

| 改前 | 问题 | 改后 |
|---|---|---|
| `开始训练，居家减脂 · 4 周，共 9 组` | 报的是整份计划名，不是今天练什么 | `开始训练，上肢与核心，3 个动作，共 9 组` |
| `第 1 组，共 3 组，俯卧撑，10 次` | 循环里每轮都从第 1 组重来 | `俯卧撑，第 1 组，共 3 组，10 次` |
| 循环 3 轮 × 2 组时报「共 2 组」 | 实际要做 6 组 | 组序按动作累计，报「第 5 组，共 6 组」 |
| `休息 90 秒，接下来：主训练` | 报区块名，听着不知道下一组做什么 | `休息，1 分 30 秒，接下来：平板支撑，40 秒` |

三条口径（改代码前先看这个）：

1. **「组」只在两个尺度上出现**：开始语是全天总量，每组是**该动作的累计**序号。同一句话里不混用。
2. **动作名前置**。`俯卧撑，第 2 组，共 3 组，10 次`——连着听时先知道做什么，不会把「第 1 组」误听成全天进度。
3. **跨区块休息报下一个动作，不是区块名**。区块名对训练中的人没有动作价值。

循环 / 超级组的累计口径同时改了 `WorkoutFlowModel`（`setIndex` 与 `setCounts`）与 `WorkoutAnnouncementBuilder`，UI 的「第 N 组 / 共 M 组」跟着一起变——两边共用同一份口径，不会界面一套、播报另一套。

核对工具：`scripts/voice-dump.sh`，直接编译 `DongKeCore` 打印三种计划形态的完整播报序列，改文案后必跑。

```bash
scripts/voice-dump.sh                        # 用已编译的二进制
DK_VOICE_DUMP_REBUILD=1 scripts/voice-dump.sh # 强制重编
```

## 6.24 AppIcon 与隐私清单（2026-10-24）

上架（甚至 TestFlight / Archive）前必须有的两件，之前一直缺：

**`DongKe/Assets.xcassets`**：目前只有 `AppIcon.appiconset`，单张 1024×1024（Xcode 会自己生成各档尺寸）。主题是「AI 制定 → 按它执行」：青绿渐变底（`Theme.tint` / `Theme.tintDark` 同款色值）+ 三行清单（首行打勾 = 正在执行）+ 右上角火花（AI 生成的标记）+ 背景一道极淡的进度环。60px 小尺寸下三行与火花仍可辨。嫌不好看就换 PNG，**名字和 `Contents.json` 别动**；要重渲改 `Tools/IconRender/main.swift` 后：

```bash
swiftc -O -o /tmp/icon-render Tools/IconRender/main.swift
/tmp/icon-render DongKe/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
```

**出口合规**：`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`（`project.yml`）。App 只用系统 HTTPS/TLS 访问用户自配的 AI 端点，不含自有或强加密，属于标准豁免，不用每年交年度自查报告。**若将来引入自研加密（如自定义协议加密层），这条要改回并补申报。**

**`DongKe/PrivacyInfo.xcprivacy`**：Apple 2024 起强制。申报了两条——

| 项 | 值 | 为什么 |
|---|---|---|
| `NSPrivacyAccessedAPITypes` | `UserDefaults` + 理由 `CA92.1` | 断点续练、别名记忆、播报开关都存 UserDefaults，只读本 App 自己的数据 |
| `NSPrivacyCollectedDataTypes` | `UserContent`（不关联身份、不用于追踪、目的 `AppFunctionality`） | 一句话生成的句子会发到**用户自己填的** AI 端点。训练记录、档案只存本机 SwiftData，不发出去，所以不申报 |

`NSPrivacyTracking` 为 false，`NSPrivacyTrackingDomains` 为空——没有任何追踪。

**两条要人工过目**：一是 UserContent 这条申报的是「会发到用户自配端点」，如果将来加了自家服务端或统计 SDK，这条要跟着改；二是 App Store Connect 的「App 隐私」营养标签要和这份清单口径一致，别一边说收一边说不收。

## 6.25 跑测试必须用 Python 包一层（2026-10-24）

**症状**：`xcodebuild ... test` 把测试全跑完了，进程却不退出，无限打印

```
IDESchemeActionSDKRecord: operatingSystemBuild ... invalidDigitCount(94232)
```

测试其实 3 秒就跑完了，日志里 `Test run with 519 tests` 也在，但 `xcodebuild` 永远挂着。**Xcode 27 解析 5 位 build 号失败后进入死循环**，与本项目代码无关。

**不要做的事**：

- 别用 `timeout 200 xcodebuild ...` —— macOS 没有 GNU `timeout`，报 `command not found`，然后 grep 拿到空输出，**很容易被误读成「测试通过」**
- 别因为「卡住」就怀疑模拟器、重启模拟器、重装 App——那是把工具链问题当环境问题
- 别只看 `grep -c "error:"` 等于 0 就收工

**做法**：分两步 + Python 控进程 + 从日志判读。

```bash
# ① 单独编译测试包（这条会正常退出）
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'id=D16A8318-973E-45CE-936B-94F5FFE3E0EC' \
  -derivedDataPath DerivedData build-for-testing \
  OTHER_SWIFT_FLAGS=-disable-sandbox 2>&1 | grep -E "error:|BUILD"
```

```python
# ② Python 跑、超时 kill、结果从日志读
import subprocess
cmd = ["xcodebuild", "-project", "DongKe.xcodeproj", "-scheme", "DongKe",
       "-destination", "id=D16A8318-973E-45CE-936B-94F5FFE3E0EC",
       "-derivedDataPath", "DerivedData",
       "-only-testing:DongKeCoreTests", "test-without-building"]
with open('/tmp/dktest.log', 'w') as f:
    p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
    try:
        p.wait(timeout=90); print("正常退出", p.returncode)
    except subprocess.TimeoutExpired:
        p.kill(); p.wait(); print("超时结束（日志已保留）")
```

```bash
# ③ 判读只认这三行，不认退出码
grep -E "Test run with|✘ Test \".*\" failed|error:" /tmp/dktest.log | tail -15
```

**为什么这招管用**：`test-without-building` 省掉了编译期，从启动到跑完不到 10 秒；90 秒够它跑完，也够在卡死时及时止损。`kill()` 之后再读日志，日志已经落盘，结果完整。

**`OTHER_SWIFT_FLAGS=-disable-sandbox` 不是可选项**（2026-10-24 复测）。省掉它，`DongKeCore` 会报一串：

```
external macro implementation type 'ObservationMacros.ObservableMacro' could not be found for macro 'Observable()';
'/Applications/Xcode.app/.../swift-plugin-server' produced malformed response
```

出处是 `VoiceInputMachine.swift` 的 `@Observable`。**绕过外层沙盒重跑同样失败**——挡的是 Swift 宏插件自己的 `sandbox-exec`，不是 WorkBuddy 的沙盒。所以别再往「权限」方向查，直接加参数。

**为什么值得固化成规定**：这次排查花了三轮才定位——先怀疑模拟器（重启了一次）、再怀疑 `timeout`、最后才想到是 xcodebuild 自己在刷日志。**同一个「卡住」对应四种原因，它就不是判据**。规矩定在这里，下次直接照抄，不再重新怀疑一遍。

同一套写法推广到所有会挂住的长命令：`xcrun simctl`、真机 `devicectl`、`swift test`。

## 6.26 动作图示的真实来源（2026-10-24）

**`ARCHITECTURE.md` §12 写的「自绘参数化骨架」不是现在的实现**，别照那节去做。实际用的是开源 SVG 素材转 path，那节留作早期方案存档。

| 项 | 事实 |
|---|---|
| 素材源 | [bryllim/workout-guide](https://github.com/bryllim/workout-guide)，源自 Everkinetic，**CC BY-SA 4.0** |
| 本地副本 | `.scratch/figure-and-glass/assets/workout-guide-main/packages/workout-guide/assets`（302 个动作，每个 3 帧） |
| 生成器 | `.scratch/figure-and-glass/tools/gen_figures.py`，**手工跑，不进构建** |
| 产物 | `DongKeCore/Figure/GeneratedFigureData.swift`（3MB，已入库，别手改） |
| 覆盖 | 动作库 39 个 → **31 个有专属图**，8 个回落到 `_generic` |

补一个动作的图示，只需在 `gen_figures.py` 的 `MAPPING` 加一行 `catalogId: 上游 slug`，然后：

```bash
python3 .scratch/figure-and-glass/tools/gen_figures.py
```

**slug 必须按名字在 302 个目录里搜出来核对，不能凭中文名猜。** 这次就有两条踩坑：

| 踩的坑 | 实际 | 后果 |
|---|---|---|
| `march_in_place`（原地踏步）→ `walking` | 素材画的是**跑步机** | 客厅原地踏步的用户看到跑步机会以为走错页面，已撤回 |
| `hamstring_stretch`（腘绳肌拉伸） | 素材是**站姿脚放高处**，不是坐姿 | 文字已改成站姿，图示是权威、文字服从它 |

### 八个没有素材的动作

`hip_circle` / `scapular_circle` / `ankle_circle` / `neck_stretch` / `thread_needle` / `back_stretch` / `dumbbell_floor_press` / `march_in_place`。302 个素材里用宽泛关键词（neck / trap / circle / floor / thread / march）全搜过，确实没有。

**不要用近似素材顶替**：这 8 个里每一个的"最近候选"都会传达错误姿势（跑步机、卧推图给地板卧推、婴儿式给仰卧抱膝）。

**也不要手绘。** 做过样张对比，手绘线稿与 Everkinetic 的精细解剖图差一个量级，同屏会出现两套视觉语言，用户会认为 app 没做完。真要补只有两条路：找同源素材，或者按 `FIGURE-STYLE.md` §2.1 的实测常数描线复刻。**「Everkinetic 完整库比 bryllim 大」这个期待已经证伪**——根目录的 `everkinetic-data/` 就是那个「完整库」，277 个动作，是 bryllim 的上游 raster 母本；8 个缺图一个也补不上（见 `FIGURE-STYLE.md` §6）。

UI 上的处理：`FigureLibrary.hasArtwork(for:)` 返回 false 时，详情页写「这个动作暂时没有示意图，按下面的要点做」，不再写「轻点图示可播放」。

根目录的 `everkinetic-data/`（27 MB）**不入库**，已写进 `.gitignore`：它是离线参考，不是 App 资源。仓库自带的 LICENSE 是 GPL-3.0，而上游 `everkinetic/data` 才是 CC BY-SA 4.0——**别把原始文件复制进 bundle**。要矢量就去上游的 `dist/svg/`。

## 6.27 动作 id 合并表（2026-10-24）

**为什么现在就要有**：动作库 39 → 几百，id 一定会动。改一个 id，`planJSON` 里的 `catalogId`、`AliasMemory` 里的记忆、`regressionId` 三处会静默指向不存在的条目——不崩、不报错，只是详情页打不开、图示退占位、低阶替代点了没反应。这类问题上线后才被发现，代价最高。

**做法**：`DongKeCore/Models/ExerciseMergeMap.swift`。语义是「旧 id 折到现存 id」，当前表为空，等真改 id 时再补。

三处与参考实现（GymMane 的 `kMergedExercises`）不同，都是踩过它的问题：

| | GymMane | 我们 |
|---|---|---|
| 链式 A→B→C | 只查一层，A 停在 B | init 时算好闭包，A 直接到 C |
| 成环 A→B→A | 不检测（靠人工保证扁平） | 原样返回 + `cycles` 报出 |
| 批量去重 | 遍历时顺手跳过重复 | `merging()` 保首次出现顺序 |

接入点只有两个：`ExerciseLibrary.entry(for:merging:)` 和 `ExerciseAliasResolver.match(...)`。**不要在调用点各写一遍映射**，否则漏一处就等于没做。

**护栏测试**（`ExerciseMergeMapTests`，9 条）：表里每条的目标必须在 `ExerciseLibrary.identifiers` 内、`cycles` 必须为空。这两条现在是空真，等表被填上就立刻生效。

**参考材料**：`docs/specs/exercise-pool-crosswalk.md` 记了 GymMane 448 条动作与我们 39 条的对照，以及「能挪什么、不能挪什么」。三条要点：

- 动作名称/肌群/器械/难度是事实性数据，可用；`steps` 英文指导语是 CC BY-SA 表达性内容，**不要照抄**
- 388 张图里 300 张来自我们已有的 bryllim 302，剩 88 张全是器械向——**图示没有增量**
- 448 条**一条中文都没有**，扩库的成本大头是写中文要点，不是拿数据

## 6.28 扩库时最容易漏的不是动作，是「第二份清单」（2026-10-24）

动作库从 39 扩到 43 时挖出来的。**`ExerciseLibrary` 之外还有一处地方在维护动作清单，扩库不跟就会静默失效**：

| 位置 | 漏了会怎样 |
|---|---|
| `PlanCatalog.items` | 本地生成器永远排不到新动作。上一轮 18→39 时漏了，21 条动作对生成器完全不可见，而且**没有任何测试会红** |
| `ExerciseAliasResolver.aliases` | 用户说新动作名认不出，走「猜」的降级路径，校对页标橙 |
| `gen_figures.py` 的 `MAPPING` | 新动作回落 `_generic` 占位图，同样是静默的 |
| `FigureLibraryTests.records.count` | 这个是唯一会红的，但红在「数字不对」，不告诉你**漏了哪个动作** |

`PlanCatalog` 已改成从动作库派生（`purposes` 含 `.strength` 的进池，`isDynamic` 取 `purposes` 含 `.warmup`），核对过原 18 条四个字段能精确复现。别名与图示两处仍是手工，扩库时按下面的顺序走：

1. 动作进 `ExerciseCatalogLower/Upper/Core`（含 `cues` ≥2、`mistakes` ≥1、`regressionName` 非空）
2. 别名补 ≥3 个叫法，**并且自己的名字必须能认出自己**（`ExerciseNounTests.everyEntryHasEnoughAliases` 会查）
3. `gen_figures.py` 加 MAPPING，重跑生成器
4. 门禁数字：`FigureLibraryTests` records = MAPPING 条数 + 1、`ExerciseLibraryTests` dedicated ≥ 同数、SPEC §11

**另一个坑：`regressionId` 不等于「换动作」。** 深蹲降阶到靠墙静蹲，两个都压膝——那是「更轻的做法」。要表达「完全绕开不适部位」用 `alternativeId`（§5.6）。之前 `PlanSafetyChecker` 拿 `regressionId` 判「可换成」，而库里所有降阶目标都命中同样的部位，那条分支恒为空。

**康复类动作要同时满足三条**，缺一条就会出问题：

| 字段 | 值 | 缺了会怎样 |
|---|---|---|
| `affectedParts` | `[]` | 标上部位的话，用户在「哪里不舒服」里选中它，这个动作会被自己的警告标红——而它正是开给用户的 |
| `relievedParts` | 受益部位 | 校对页不会推荐它，「加法」还是没做 |
| `purposes` | `[.mobility]`，**不含 `.strength`** | 会被排进训练主项。`PlanCatalog` 的入选条件就是 `purposes.contains(.strength)` |

`PlanSafetyChecker.reliefs` 里还有一条运行时约束：推荐的动作必须 `affectedParts` 与不适部位不相交，写成了测试 `reliefsDoNotConflictWithItself`。

## 7. 换机后容易踩的坑

1. **`xcodegen generate` 会改脏 `DongKe.xcodeproj`**：这个目录是入库的（与早期说法相反，`git ls-files` 可查），所以每次生成工程都会在 `project.pbxproj` / `DongKe.xcscheme` 里留 diff。改 `project.yml` 后**必须**重跑生成并一起提交，否则别人拉到的是旧工程。
2. **把历史红当环境问题**：先看 `docs/GATE-2-TEST-REPORT.md` 的红转绿顺序（该报告是 2026-10-22 的历史快照，当前已全绿）。
3. **骨架门禁红被当成回归**：打样期数据只有 2 帧，动态动作欠第 3 帧。判红前先核对 `figure-specs` 数据版本，见 SPEC §11 最后一条。
4. **`git push` 直连 22 端口超时**：本机走代理。本地代理在 `127.0.0.1:7890` 时用
   `git -c core.sshCommand="ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'" push origin main`。
   港区/公司网络换端口就换这一段，别去改 remote 地址。
