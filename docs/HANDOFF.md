# 换机接手说明

本文是给人看的交接单，不是规范。规范只有两份：`docs/FROZEN-BASELINE.md` 与 `docs/SPEC.md`。

## 1. 当前状态

| 项 | 状态 |
|---|---|
| 方案门 | 已放行（用户「方案通过」） |
| 文档 | 已冻结。PRD / ARCHITECTURE / UIUX 只作存档依据，冲突时以 FROZEN + SPEC 为准 |
| 工程 | `project.yml`（XcodeGen）已可生成 `DongKe.xcodeproj`；DongKeCore framework + DongKe app + DongKeCoreTests |
| 代码 | Domain 已实现（JSON 抽取 / 解码 / 校验 / 归一 / 自由文本解析 / 执行流 / 休息状态机 / 周排程 / 完成率 / 计划生成 / 导入编排 / 动作库）+ 图示模块（开源素材 / 可换源 / 点按播放）+ 玻璃材质层。SPEC §7 的 12 页清单里已落地 11 页：引导 5 屏、今日、训练执行、休息、完成总结、计划、计划导入（粘贴 → 校对 → 保存）、动作库、动作详情、记录、设置 |
| 数据 | 训练记录、档案、计划三份数据走 SwiftData；提醒按计划排程（≤7 条、先清后排）；计划由引导档案生成，也可粘贴文本 / JSON 导入 |
| 测试 | 132 条 Swift Testing，**132 绿 0 红**（`ios-run.sh test`） |
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

预期：生成工程成功；测试跑完 132 条，全部通过。若出现大量失败，先看 `~/.workbuddy/skills/ios-build-test/scripts/ios-run.sh probe` 的模拟器探测结果，别先怀疑代码。

## 4. 专家团怎么续上

专家团本身跟着账号走，不跟着机器走；但**团队成员的对话上下文不迁移**——换机后是全新的三个角色，它们只知道你这次告诉它们的东西。

1. 新机器装 WorkBuddy，登录同一账号。
2. 左侧「专家」→ 选 `MvpDevExpertTeam`（与旧机同一个专家包）。
3. 首条消息把下面这段整套粘进去，不要只说「继续」：

> 接手动刻（DongKe）项目，仓库已 clone 在本机。先按顺序读：`docs/HANDOFF.md`（本文件）、`docs/FROZEN-BASELINE.md`、`docs/SPEC.md`、`docs/GATE-2-TEST-REPORT.md`、`.workbuddy/memory/2026-10-22.md`。
> 铁律：开发唯一依据是 FROZEN + SPEC，PRD / ARCHITECTURE / UIUX 只作存档，不许再跨角色对账或改写文档。
> 现状：文档已冻结，Gate 2 报告已出，52 条测试 38 红，等用户放行。
> 现在只做一件事：复述你读到的 MVP 范围、三条硬口径（字体零打包 / 占位键 `_generic` / 帧数动态 3 静力 2），以及红转绿顺序，然后停下等我放行。不要写代码，不要改文档。

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
| `DongKe/DesignSystem/` | 主题令牌与玻璃修饰器（`glassSurface`），页面不得出现字面量颜色 |
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

要加一种新格式，只加一个适配器产出 `PlanDraft`，编译器与页面都不用动。要给某个 agent 定契约，让它照
`PlanPromptTemplate.text` 的 JSON 输出——那份示例由测试保证能被自己的解析器读懂。

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
SIMCTL_CHILD_DK_PREVIEW=import SIMCTL_CHILD_DK_IMPORT_SAMPLE=1 xcrun simctl launch booted app.dongke.ios  # 直接看校对页
xcrun simctl io booted screenshot /tmp/shot.png
```

注意必须先 `terminate`：App 已在运行时 `launch` 不会重启进程，环境变量不生效。

玻璃分支判断是 `#available(iOS 26)`，因此**任何 ≥26 的运行时都走原生分支**；要验证回退观感只能用 `DK_FORCE_LEGACY_GLASS=1`，不要指望装 iOS 26 运行时能覆盖到。

## 7. 换机后容易踩的三个坑

1. **`.xcodeproj` 不在库里**：只 clone 不跑 `xcodegen generate`，Xcode 打开一片空白。
2. **把 38 条红当环境问题**：先看 `docs/GATE-2-TEST-REPORT.md` 的红转绿顺序，空实现桩本来就是红的。
3. **骨架门禁红被当成回归**：打样期数据只有 2 帧，动态动作欠第 3 帧。判红前先核对 `figure-specs` 数据版本，见 SPEC §11 最后一条。
