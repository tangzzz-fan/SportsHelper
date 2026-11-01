# SportsHelper 项目长期记忆

> **细节不在这里。** 机制与口径的唯一维护点在仓库里：`docs/HANDOFF.md`（怎么干活、踩过的坑）、`docs/specs/BACKLOG.md`（每个决策的证据、试过又撤回的方案）、`docs/FLOW.md`（主流程）、`docs/adr/0001–0007`（四条硬约束）。本文件只留「一进来就会踩」的东西。

## 验收与门禁

- **验收 = 单测全绿**，没有第二档。UI 测试已整体删除（理由见 HANDOFF §6.6），`Shared/A11yIdentifiers.swift` 保留给 VoiceOver。
- 改了 `DongKe/Services`（AI 客户端 / 语音 / TTS）自己上模拟器点一遍那个功能——那里没有自动化兜底，写在明处。
- 单文件 **≤500 行（不含空行）**，门禁扫 `DongKe/ DongKeCore/ DongKeCoreTests/ Shared/`。
- 加动作只动三处：`ExerciseCatalog{Lower,Upper,Core}`、`ExerciseAliasResolver.aliases`（≥3 叫法且认得出自己）、`gen_figures.py` 的 MAPPING + `FigureLibraryTests.records`。`PlanCatalog.items` 已派生，不用动。
- **ARCHITECTURE 会撒谎**（§12 仍写「自绘参数化骨架」，实际是 workout-guide 的 SVG path）。改完文档跑一次类型名比对，别靠人读。

## 跑测试：必须 Python 包一层

`xcodebuild test` 跑完**不退出**（Xcode 27 解 5 位 build 号死循环）。三步：`build-for-testing` → Python `Popen` + `wait(90)` + `kill()` → 只认日志里的 `Test run with` / `✘ Test`，**不认退出码**。`OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'` 是必需项，否则 `@Observable` 报 malformed response。macOS 没有 GNU `timeout`。

## 环境

- 模拟器 UDID `D16A8318-973E-45CE-936B-94F5FFE3E0EC`；`content_size` 保持 `large`，不要设 AX3 当常规验收。
- 推 origin 要代理：`git -c core.sshCommand="ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'" push origin main`
- BSD grep 不支持 `\|` 交替，会**静默返回空**——用 `grep -E` 或 rg。看到空结果先怀疑模式。

## 已定调，别再讨论

- 不用 AI 也能开始（ADR-0001）；计划只因用户点的「采纳」而变（ADR-0004）；完成率与剂量分账（ADR-0006）；播报一拍一句、封闭词表（ADR-0007）。
- 素材是 bryllim/workout-guide（衍生自 Everkinetic，CC BY-SA 4.0），上架前 share-alike 与署名要处理；`VoiceClips/*.wav` 是 macOS `say` 产物，**不能随包上架**。
- 内置 Key 走 `DongKe/Resources/ai-defaults.json`（已 gitignore），**上架前必须摘掉**。
- 界面里贴底面板的布局约束（不写死高度、`onCardHeightChange`/`restingInset`、别把超宽视图放进 ZStack、`clipped()` 会裁覆盖层）只在 `.workbuddy/memory/2026-10-25.md` 记过，改那块先读它。
