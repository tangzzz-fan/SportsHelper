# 换机接手说明

本文是给人看的交接单，不是规范。规范只有两份：`docs/FROZEN-BASELINE.md` 与 `docs/SPEC.md`。

## 1. 当前状态

| 项 | 状态 |
|---|---|
| 方案门 | 已放行（用户「方案通过」） |
| 文档 | 已冻结。PRD / ARCHITECTURE / UIUX 只作存档依据，冲突时以 FROZEN + SPEC 为准 |
| 工程 | `project.yml`（XcodeGen）已可生成 `DongKe.xcodeproj`；DongKeCore framework + DongKe app + DongKeCoreTests + DongKeUITests；`Shared/A11yIdentifiers.swift` 同时编进 App 与 UI 测试 |
| 代码 | Domain 已实现（JSON 抽取 / 解码 / 校验 / 归一 / 自由文本解析 / 执行流 / 休息状态机 / 周排程 / 完成率 / 计划生成 / 导入编排 / 动作库 / 图示 / AI 契约 / 断点策略 / 通知负载）+ 图示模块（开源素材 / 可换源 / 点按播放）+ 玻璃材质层 + AI 直连（Keychain / 提示词 / 三级降级 / 错误映射）+ 训练执行收尾（组级明细 / 跳过三态 / 30 分钟断点续练 / 前台通知与深链 / 触觉声音）+ 设置页收尾（AI 配置 / 关于 / 清空全部数据）+ 今日页提醒健康条。SPEC §7 的 12 页清单里已落地 11 页：引导 5 屏、今日、训练执行、休息、完成总结、计划、计划导入（粘贴 → 校对 → 保存 / AI 生成）、动作库、动作详情、记录、设置（提醒 + AI + 关于 + 清空） |
| 数据 | 训练记录、组级明细（三态 + 跳过原因）、档案、计划走 SwiftData；断点存在 UserDefaults `dk.workout.checkpoint`（30 分钟内有效）；提醒按计划排程（≤7 条、先清后排）+ 休息计时临时通知；计划由引导档案生成，也可粘贴文本 / JSON 导入，或走用户自填的 AI 端点生成 |
| 测试 | **227 条 Swift Testing 全绿**（`-only-testing:DongKeCoreTests`）+ **8 条 UI 测试全绿**（`-only-testing:DongKeUITests`）；AI 契约 38 条、断点续练 9 条、通知负载 6 条、提醒健康度 9 条、导入标题 3 条 |
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

预期：生成工程成功；单测 227 条 + UI 测试 8 条，全部通过。若出现大量失败，先看 `~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh probe` 的模拟器探测结果，别先怀疑代码。

**必须分两次跑**，不要指望一条命令全绿：

```bash
~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh test --project DongKe.xcodeproj --scheme DongKe -only-testing:DongKeCoreTests
~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh test --project DongKe.xcodeproj --scheme DongKe -only-testing:DongKeUITests
```

原因：脚本看到第一条 `Executed N tests` / `Test run with N tests` 就认为「结论已出」，再等 20 秒仍不退出就 SIGTERM。跑完单测后 UI 测试还没开始，就会被这条宽限掐掉。跑单类/单目标时它是对的，跨目标必须分开调用。

另外 `ios-run.sh` 的尾巴会打 `Executed 0 test` + `TEST SUCCEEDED`——XCTest 计数器不认 Swift Testing，单测真实结果看日志里的 `Test run with 227 tests`。UI 测试是 XCTest，看 `Executed 8 tests`。

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

## 6.3 训练执行的三条不变量

| 不变量 | 位置 | 破坏后的表现 |
|---|---|---|
| 每完成 / 降阶 / 跳过一组，都要同时写 `SetLogEntity` 与 `dk.workout.checkpoint` | `WorkoutSession.appendLog` → `saveCheckpoint` | 历史里降阶率恒 0；杀进程后断点丢一组 |
| 断点只在 **30 分钟内**、且 `stepIndex < totalSteps` 时可续；训练正常结束必须 `clear()` | `WorkoutResumePolicy.canResume` / `saveCheckpoint` | 昨天没做完的计划第二天还弹「继续训练」 |
| 休息的 `endAt` 是绝对时间；通知与触觉都由状态机的 effects 驱动，不由 View 自己计时 | `RestTimerStateMachine` → `syncRestNotification` → `Haptics.restFinished` | 锁屏回来倒计时跳变、或归零没声音 |

休息通知标识固定 `dk.rest.<sessionId>`（`RestNotificationBuilder.prefix`），排程前先清同前缀，绝不碰 `dk.plan.`。通知负载：训练提醒带 `dk.weekday`，休息通知带 `dk.dayIndex`，点击统一由 `NotificationRouter` 解成 `WorkoutDeepLink` 交给 AppShell。

## 6.4 清空全部数据

入口在设置页底部，走 `DataResetService.clearAll`：删五张表（SetLog / Session / Plan / Profile / UserExercise）→ 清 `dk.` 前缀的全部 UserDefaults → 删 Keychain 里的 AI Key → 取消 `dk.plan.` 与 `dk.rest.` 待触发通知。完成后 `AppShell.handleEraseAll` 重新 load 各 store 并弹回引导。

验证方式（模拟器可复现）：`DK_COMPLETE_ONBOARDING=1` 建数据 → 杀进程 → `DK_ERASE_ALL=1` 跑一次 → 杀进程 → 裸启动应回到引导第一屏。注意 `simctl` 有两台 booted 模拟器时一律**写 UDID**，`booted` 会解析到另一台。

## 6.5 文件拆分（2026-10-23）

SPEC §4「单文件 ≤300 行」已全量满足。拆分方式分两种，**都是纯移动、无行为改动**：

| 类型 | 做法 | 例子 |
|---|---|---|
| 多个并列视图 | 按类型边界切成独立文件 | `ExerciseLibraryView` → `UserExerciseDetailView` / `ExerciseDetailView`；`ImportView` → `PlanReviewView` / `PlanEditSheet`；`TodayView` → `TodayView+Cards` / `ProgressBar` |
| 单个大类型 | 用 `extension` 拆到 `+Flow` / `+State` / `+Dose` / `+Text` / `+Aliases` 等文件 | `WorkoutSession`、`DraftLineScanner`、`OnboardingView`、`PlanGenerator`（目录数据抽成 `PlanCatalog`） |

**代价（必须知道）**：extension 分布在多个文件时，`private` 成员互不可见，所以被拆类型的部分成员从 `private` 放宽成了模块内可见（如 `TodayView.store`、`OnboardingView.draft/step`、`WorkoutSession.logs/rest`）。这是模块内部可见性，不对外暴露；但**别再往这些类型上加新的公开面**，要加就加在新的 extension 文件里。

**仍欠**：SPEC §10 的「字号不得硬编码」未收口——全仓仍是 `.font(.system(size:))` 字面量。做这件事要先定一套语义字阶（display/title/body/caption…）再一次性迁移，半迁移比不迁移更糟，所以单列一票。

## 6.6 UI 测试（2026-10-23）

`DongKeUITests` 是 XCTest 目标（Swift Testing 不支持 XCUIApplication），八条用例覆盖四条主链路：引导五步 / 导入粘贴→识别→校对→保存 / 训练→休息→跳过→总结 / 设置开关与清空。

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

## 7. 换机后容易踩的三个坑

1. **`xcodegen generate` 会改脏 `DongKe.xcodeproj`**：这个目录是入库的（与早期说法相反，`git ls-files` 可查），所以每次生成工程都会在 `project.pbxproj` / `DongKe.xcscheme` 里留 diff。改 `project.yml` 后**必须**重跑生成并一起提交，否则别人拉到的是旧工程。
2. **把历史红当环境问题**：先看 `docs/GATE-2-TEST-REPORT.md` 的红转绿顺序（该报告是 2026-10-22 的历史快照，当前已全绿）。
3. **骨架门禁红被当成回归**：打样期数据只有 2 帧，动态动作欠第 3 帧。判红前先核对 `figure-specs` 数据版本，见 SPEC §11 最后一条。
