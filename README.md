# 动刻 DongKe

把一份运动安排变成「今天做什么、做几组、休息多久」的执行日程。

iOS 18+ ｜ SwiftUI + SwiftData + Swift 6 ｜ 零第三方依赖 ｜ 无账号、无后端、无遥测 ｜ 生产代码 1.97 万行，单测 0.97 万行

---

## 1. 它解决的不是「练什么」

AI 已经把「练什么」解决得过剩。断点在第二天：

计划在 ChatGPT 的对话里活着，而执行记录不在那里。于是它是一段散文——训练时要滑屏找下一个动作，组间休息靠心算，做不动时没有出口，第三周对话被淹没，计划就死了。

Keep / Fitbod / Hevy 都在竞争「生成」，没有产品竞争「生成之后怎么把它执行掉」。动刻只做后半段：**接管你已经信任的那份安排，不生产安排。**

这也是这个仓库所有设计取舍的源头——凡是让「执行」更顺的，做；凡是让 App 变成第二个计划来源的，不做。

---

## 2. 四条硬约束（外加一条工程侧）

这四条不是偏好，是**改代码前必须先看一眼**的边界。每条都有 ADR，且都在测试里有守卫。

| 约束 | 含义 | 违反后的表现 |
|---|---|---|
| **不用 AI 也要能开始**（ADR-0001） | 引导最后一屏就用本地规则生成一份计划，零输入、零 Key、零网络 | AI 一旦不可用，产品就没有入口 |
| **计划只因用户点的「采纳」而变**（ADR-0004） | 没有任何自动生效路径。系统只能提案，用户点了才落库 | App 在用户不知情时改了他的处方 |
| **外来计划不主动提建议**（ADR-0003） | 粘贴 / AI 来的计划，提案只在「调整」入口里出现；自有的才在计划页主动出，一周一次 | 一边说「这计划可能写错」，一边劝他改——两句话不能同时成立 |
| **完成率与剂量分账**（ADR-0006） | 额外加做的组只进剂量，不进完成率分母，也不让「这一节练过没有」成立 | 跳过一组再加两组，完成率会被抬到 100% 以上 |

第五条是工程侧的：**播报只允许封闭词表**（ADR-0007）。主题名、区块名这类 AI 生成的字符串不进口播，否则整句回落系统 TTS，一节课里两种音色。

---

## 3. 一次训练发生了什么

```
引导 5 屏 ──→ 本地规则生成计划 ─┐
粘贴文本 / 表格 ──→ 解析 ───────┼──→ 校对页 ──→ 保存 ──→ 排提醒（≤7 条）
说一句话 ──→ 解析约束 ──→ AI ───┘

今日页 / 通知深链 ──→ 训练执行 ──→ 每组落盘
                        │              │
                        │              └──→ 记录：有效组 · 这周练到哪儿 · 为什么没做
                        └── 30 分钟内退出 ⇒ 断点续练

记录 ──→ 剂量规则（纯函数，不联网）──→ 提案卡 ──→ 用户点「采纳」──→ 计划 +1 版
```

三条入口都**必须**过校对页才能落库——AI 生成什么就覆盖现有计划，用户没有反悔机会，这条 2026-10-24 修过一次。

完整流程图与「画图时最容易漏的六条」在 [`docs/FLOW.md`](docs/FLOW.md)，那里是流程的唯一维护点。

---

## 4. 剂量回路：这个 App 与「记组数 App」的分界

训练记录只进不出，是「第三周计划就死了」的直接原因。所以记录必须回到处方上——但**只能经过用户**。

**剂量 = 一周里落在某个肌群上的有效组数。** 不是动作数，也不是练了多久：十个动作各一组与三个动作各三组，动作数差三倍，剂量可能一样。判定看自评余力（`rpe ≥ 2` 才算有效），不看有没有点「完成」。

证据分三级，方向相反：

| 证据 | 判据 | 能动什么 |
|---|---|---|
| 强证据（真的多做了） | 连续两次、**每组**都 ≥ 目标 + 1 | 加量：次数 → 负重 → 组数，取最低那一档 |
| 弱证据（说还有余力） | 连续两次、**最后一组**记「还能做三次以上」 | **只加次数 +2**，负重与组数不动 |
| 减量 | 疼（1 次即触发，7 天内）/ 太累（2 次）/ 没时间（3 次且那天 > 5 个动作） | 保护 > 重建 > 换动作 > 剂量 |

一次只出一张提案，优先级 `保护 > 重建 > 换动作 > 剂量`。拒绝要被记住：同一条不再提，连拒三次整体安静，只有采纳才清零；降量绕过拒绝记忆——疼这件事，系统宁可重复一次。

`revision` 是「第几版」，不是「改了几次」：首次生成是 1，**只在采纳时 +1**，未采纳不计数。它同时是重排的随机种子，`variation = 0` 必须与不传时逐字节一致，否则老用户重启会看到计划自己变了。

记录页是这条回路的读数面板：本周有效组、每个肌群一条横条（与上周比 ↑2 / ↓1 / 持平 / 新）、四周趋势、五个跳过原因的分布。没有这块面板，回路的产出只停在提案卡上，用户感受不到自己在变强。

---

## 5. 数字

| 项 | 值 |
|---|---|
| 动作库 | 58 条（下肢 26 / 上肢 21 / 核心 11），35 条有三帧矢量图，23 条回落 `_generic` 占位 |
| 图示 | 矢量 `Path`（非位图、非 GIF），36 条记录 = 35 + 1 占位；素材 bryllim/workout-guide（CC BY-SA 4.0） |
| 代码 | `DongKeCore` 93 文件 / 1.01 万行；`DongKe` 79 文件 / 0.96 万行 |
| 测试 | 69 文件 / 0.97 万行 / 762 个 `@Test`。**只有单测**，UI 测试已整体删除 |
| 依赖 | 0（无 SPM、无 Pod；仅 Apple 框架） |
| ADR | 7 条；另有 `docs/specs/BACKLOG.md` 15 节，记着每个方案的证据与「试过又撤回」 |

---

## 6. 结构

```
DongKeCore/          纯逻辑 framework，只 import Foundation + Observation
  Models/            动作库、计划、档案、会话、肌群、目标
  Import/            适配器链：任意 JSON / 表格 / 列表 / 散文 → PlanDraft → WorkoutPlan
  Parsing/           解码、校验、归一、安全检查、导入编排
  Scheduling/        本地计划生成、周排程、通知负载、剂量报告、历史统计
  Workout/           执行流、休息状态机、会话账本、剂量规则、播报文案、断点
  AI/                BYOK 契约：提示词、请求体、三级降级、响应映射、传输层
DongKe/              App 层
  Features/          今日 / 计划 / 训练 / 休息 / 总结 / 记录 / 导入 / 动作库 / 设置 / 引导
  DesignSystem/      语义 token、`Typography`、`Icons.swift`（SF Symbols 唯一入口）
  Data/              SwiftData 实体与 Store，断点与别名记忆
  Services/          URLSession（全仓唯一）、Keychain、语音转写、系统 TTS
DongKeCoreTests/     Swift Testing，纯逻辑，不依赖模拟器 UI
```

两条结构上的取舍：

- **`DongKeCore` 是 framework 而不是目录**，因为它要能被单测直接编进去，且不碰 SwiftUI / UIKit / AVFoundation。所以状态机、排程、剂量全在这里，视图只剩排版——「什么时候该说话」是产品规则，不该埋在 App 里靠手测。
- **导入是一个适配器链**。加一种新格式只加一个适配器产出 `PlanDraft`，编译器和页面都不用动。库外动作不拦不扔：猜（标橙待确认）→ 记（别名记忆）→ 存（`custom_<slug>` 存为「我的动作」）。

---

## 7. 跑起来

```bash
xcodegen generate                       # 工程由 project.yml 生成，.xcodeproj 也入库
```

```bash
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'id=<SIMULATOR_UDID>' -derivedDataPath /tmp/dk \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' build-for-testing
```

`-disable-sandbox` **不是可选项**：缺了它所有 `@Observable` 报 `swift-plugin-server produced malformed response`（挡的是 Swift 宏插件自己的沙盒，不是外层沙盒）。

跑测试要在外面包一层 Python：

```python
import subprocess
cmd = ["xcodebuild", "-project", "DongKe.xcodeproj", "-scheme", "DongKe",
       "-destination", "id=<UDID>", "-derivedDataPath", "/tmp/dk",
       "-only-testing:DongKeCoreTests", "test-without-building"]
with open("/tmp/dktest.log", "w") as f:
    p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
    try: p.wait(timeout=90)
    except subprocess.TimeoutExpired: p.kill(); p.wait()
```

判读只认日志里的 `Test run with` / `✘ Test "..." failed`，**不认退出码**——`xcodebuild test` 跑完不退出（Xcode 解析 5 位 build 号失败后死循环），日志才是结果。macOS 没有 GNU `timeout`，别写 `timeout 200 xcodebuild`：它会 `command not found`，然后空输出被误读成「通过」。

**人工走查钩子**（仅 `#if DEBUG`，发布构建无此分支）：`SIMCTL_CHILD_DK_PREVIEW=workout|plan|history|rest|summary|library|import|settings` 直达某一屏；`DK_ERASE_ALL=1` 走一遍清空数据；`DK_VOICE_FAKE=1` 用假 speaker 把播报写进文件。完整清单见 [`docs/HANDOFF.md`](docs/HANDOFF.md) §6.1。

---

## 8. 文档地图：文档是地层，代码是事实

这个仓库的文档比代码更早成型，因此**同一条信息在不同年代有不同版本**。读之前先看它属于哪一层：

| 问题 | 看哪里 |
|---|---|
| 今天的主流程、每个入口的归属口径 | [`docs/FLOW.md`](docs/FLOW.md)（唯一维护点） |
| 怎么干活、踩过的坑、为什么这么写 | [`docs/HANDOFF.md`](docs/HANDOFF.md)（794 行，最值得读的一份） |
| 某个机制为什么是这个形状、试过什么又撤回 | [`docs/specs/BACKLOG.md`](docs/specs/BACKLOG.md) + [`docs/adr/`](docs/adr) |
| 术语（剂量 / 余力 / 提案 / 采纳 / 纠错 / 演进） | [`GLOSSARY.md`](GLOSSARY.md) |
| 结构与契约 | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) §4–§11 |
| 图示规格（线宽 / 墨量 / 取景的量化判据） | [`docs/FIGURE-STYLE.md`](docs/FIGURE-STYLE.md) |
| 商店文案、分级、隐私问卷、审核备注 | [`docs/APPSTORE.md`](docs/APPSTORE.md) |

**`docs/FROZEN-BASELINE.md` 与 `docs/SPEC.md` 自称是「开发唯一依据」，但它们停在 2026-10-22。** 之后动作库从 18 扩到 58、图示从「自绘骨架」换成开源矢量线稿、加了一句话生成与语音播报、接了剂量回路——这些都不在冻结文档里。`ARCHITECTURE.md` §12 至今仍写着「自绘参数化骨架」，与实际实现不符。

判定「文档有没有过期」的办法只有一个：把文档里所有 `` `CamelCase` `` 抓出来，对代码里的类型名表取差集。差集就是可疑项。**纯人工读发现不了。**

---

## 9. 已知缺口

写在明处，好过假装被覆盖。

- **纯自重池撑不满五天**：60 分钟 × 5 天，臀到 42 组。改上限只会让下肢日没有腿（试过，回退）。真解是降组数或降频率，两条都没走。
- **跟练类内容没有分路**：说「我想跟着练五禽戏」，会被静默排成一份深蹲计划。ADR-0002 定了「套路不复用计划模型」，`Routine` 类型还没建。
- **已决策未落地**：套路内容包、微剂量（休息日的三分钟单动作）。
- **静态动作的强证据没开**：UI 不记录「多撑了几秒」，只走余力（弱证据）。
- **`DongKe/Services` 没有自动化兜底**：AI 客户端、语音转写、TTS 改了只能自己上模拟器点一遍。
- **上架阻断项**：内置 Key 在 `DongKe/Resources/ai-defaults.json`（已 gitignore），上架前必须从 bundle 摘掉；`VoiceClips/*.wav` 是 macOS `say` 产物，不能随包分发。

---

## 10. 素材与许可

- 动作图示来自 [bryllim/workout-guide](https://github.com/bryllim/workout-guide)，衍生自 Everkinetic，**CC BY-SA 4.0**。构建期把 SVG 路径转成 `DongKeCore/Figure/GeneratedFigureData.swift`（3 MB，生成物，别手改）。署名义务与 share-alike 在 App Store 分发下的处置**尚未完成**——上架前要处理。
- `docs/FIGURE-STYLE.md` 记着「同风格」的量化判据（线宽 / 图高 0.67%–2.90%、墨量 3%–8%、取景同档），也记着三条被否决的路：近似素材顶替、手绘、参数化自绘（三代实现都收敛到「木偶」）。
- 代码本身没有 LICENSE 文件：仓库当前是私有状态，未声明开源许可。
