# 04: Prompt 与 AI 接线

**What to build:** 把确认过的 brief 真的送进模型，并让 AI 生成也遵守用户的别名记忆与「我的动作」。

**Blocked by:** 02, 03, 05（05 是测试加固，不挡功能）

**Status:** done（2026-10-24；05 网络桩仍未做）

- [x] `AIPromptBuilder.makeMessages(profile:brief:)` / `copyablePrompt(profile:brief:)`；`userBrief` 先写「本次按原话生成」，再写档案底子
- [x] 冲突规则：brief 覆盖 weekdays / sessionMinutes / equipment / goal；level 永远取档案；injuries 与 brief.avoid 合并，只增不减
- [x] 原话原样进 prompt（解析器已截断 200 字），便于模型理解语气与偏好
- [x] 具体星期写进 prompt（「周二、周四，共 2 天」），并硬性要求 `meta.daysPerWeek` 一致
- [x] 重点部位只做倾向，不突破 18 个 catalogId 白名单；库内没有的动作仍走 `custom_`
- [x] `AIPlanGenerating` 改签名；`AIGenerateCard` 传 brief；「复制提示词」也走 `copyablePrompt(profile:brief:)`
- [x] `AIPlanInterpreter.interpret(text, memory:, exercises:)` 在 client 里传真实值，修掉 AI 路径无视别名记忆 / 我的动作
- [x] 测试：brief 覆盖四项、伤病不被移除、无 brief 时回落档案、copyable 与 messages 同源（4 条）

**遗留**：05 的 `URLProtocol` 桩未做，AI 网络层仍只有 smoke 脚本覆盖；下一票补。
