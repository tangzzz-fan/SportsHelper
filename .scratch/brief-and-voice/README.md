# 一句话生成与语音陪练 · brief-and-voice

起因（2026-10-24）：确认两件事——用户描述一句能不能生成计划、有没有语音播报。

## 核查结论

| 能力 | 现状 | 证据 |
|---|---|---|
| 一句话生成 | **半成品：链路齐全，入口缺失** | `AIPlanClient.generatePlan(profile:extraNote:)` 已支持 `extraNote`，三级降级、64KB 上限、`PlanValidator` 把关都在；但 `AIGenerateCard` 调它时写死 `extraNote: ""`，用户没有输入句子的地方 |
| 语音播报 | **没有** | 全仓无 `AVSpeechSynthesizer` / `AVAudioSession`；休息归零只有 `AudioServicesPlaySystemSound(1057)` + 触觉（AC-12 的「声音」由系统音满足，不是 TTS） |

顺带发现两处（已入票）：

- `AIPlanInterpreter.interpret(text)` 没传 `memory` / `exercises`，AI 生成会无视用户改过的别名与「我的动作」。
- `AIPlanClient` 在 App target，没有网络层测试；401 / 429 / 坏 JSON / 三级降级全靠手测。

## 已定决策（2026-10-24）

| # | 决策 |
|---|---|
| 1 | 输入方式：文字 + 语音（Speech 转写回填同一输入框） |
| 2 | 冲突口径：生成前先展示「我理解为…」；本次覆盖档案的天数 / 时长 / 器械 / 目标，**伤病只增不减**，且不写回档案 |
| 3 | 播报范围：关键节点 + 休息最后 3 秒倒数 |
| 4 | 默认关、仅前台；不申请后台音频，锁屏仍靠通知 + 触觉 |

## 票

| # | ticket | blocked by |
|---|---|---|
| 01 | 冻结文档补丁：F11 / F12 与两条决策 | 无 |
| 02 | `PlanBrief` 与本地解析器 | 无 |
| 03 | 「我理解为」确认页 | 02 |
| 04 | Prompt 与 AI 接线 | 02, 03, 05 |
| 05 | AI 传输层可测化 + 网络桩 | 无 |
| 06 | 语音输入（Speech 转写） | 03 |
| 07 | 播报文案生成器 | 无 |
| 08 | 播报引擎与开关 | 07 |
| 09 | 挂到训练流程 | 07, 08 |
| 10 | 验收：单测 / UI / 真机 | 06, 09 |

## 前沿（可立刻开工）

- 01 冻结文档补丁
- 02 `PlanBrief` 与解析器
- 05 AI 传输层可测化
- 07 播报文案生成器

## 进展（2026-10-24）

| # | ticket | 状态 |
|---|---|---|
| 01 | 冻结文档补丁 | done（F11/F12、AC-23/24、增补决策 13/14） |
| 02 | `PlanBrief` 与解析器 | done（36 条用例） |
| 03 | 「我理解为」确认页 | done（麦克风留给 06） |
| 04 | Prompt 与 AI 接线 | done（05 网络桩后补） |
| 05 | AI 传输层可测化 | done（15 条桩用例） |
| 06 | 语音输入 | todo |
| 07 | 播报文案 | done（24 条用例） |
| 08 | 播报引擎 | done（11 条闸门用例 + UI 开关持久化；触发挂载归 09） |
| 09 | 挂到训练流程 | todo |
| 10 | 验收 | todo |

下一步：01 文档补丁 + 06 语音输入；之后 07–09 播报线，10 真机验收收尾。

## 复核（2026-10-24，02–04 提交后）

双轴复核（Standards / Spec）查出并已修的：

| 问题 | 轴 | 修法 |
|---|---|---|
| `BriefConfirmView` 325 行，撞 §4.3 门禁 | Standards | 拆成 `BriefConfirmView`（状态与取材）+`BriefConfirmView+Sections`（版式） |
| 动作上限与组数上限两套公式各写一遍，且 30 分钟给「≤6 动作 / ≤15 组」= 6×3 组已 18 组，自相矛盾 | Standards | 收口到 `EffectivePlanBrief`：先定组数，动作数 = 组数/3；新增 5…120 分钟全档位一致性用例 |
| `userBrief(profile:extraNote:)` 与 `(profile:brief:)` 整段重复 | Standards | 只留 brief 版，`extraNote` 变成 `PlanBrief(sentence:)` 的薄包装 |
| `AIPlanGenerating` 两个便捷重载默认 `memory: .empty`，把 04 刚修的「无视别名记忆」重新打开 | Standards | 删除重载，协议只留全参版本 |
| 确认页「你说的 / 沿用档案」读的是**解析结果**，用户改完不重算 | Spec | 改成与档案现比：星期/时长/器械/目标与档案一致才标「沿用档案」 |
| `isVague` 只有测试在读，UI 从不消费 | Standards | 确认页加一句「没听出具体安排，下面按你的档案兜底」 |
| 按钮写 `.subheadline.weight(.semibold)` / `.footnote.weight(.medium)`，绕开 `Typography` 且同屏三档字重 | Standards | 改用 `Typography.buttonLabel` / `Typography.secondary`；去掉 `lineLimit(1)` |
| 「共 N 天」「N 分钟」没 `monospacedDigit` | Standards | 补上 |

未做（有意）：

- 重点与避开在确认页仍只读——03 的「不做」已写明不在这里改具体动作，重说比在确认页抠词更省事。
- 「复制提示词」不走确认页：它复制的是完整提示词文本，用户发出去前自己会读一遍；D2 约束的是「生成前」，不是「复制前」。
- `Tools/AISmoke` 仍复制了三档降级环，且解析时用默认 `memory`——05 会把传输层收到 Core 里，一起消掉。

## 不做

- 语音指令控制（「下一组」「跳过」只播报、不收音，避免误触发）
- 锁屏 / 后台播报（本期；要做得申请 audio 后台模式）
- 多语言、多音色、语速自定义
- 把一句话写回档案（本次约束只作用于这一次生成）
- 云端 TTS / 云端语音识别兜底
