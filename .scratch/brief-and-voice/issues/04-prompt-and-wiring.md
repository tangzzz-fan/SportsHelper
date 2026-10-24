# 04: Prompt 与 AI 接线

**What to build:** 把确认过的 brief 真的送进模型，并让 AI 生成也遵守用户的别名记忆与「我的动作」。

**Blocked by:** 02, 03, 05

**Status:** todo

- [ ] `AIPromptBuilder.makeMessages(profile:brief:)` / `copyablePrompt(profile:brief:)`；`userBrief` 先写「本次要求」，再写档案底子
- [ ] 冲突规则：brief 覆盖 weekdays / sessionMinutes / equipment / goal；level 永远取档案；injuries 与 brief.avoid 合并，**只增不减**
- [ ] 原话原样进 prompt（截断 200 字），便于模型理解语气与偏好
- [ ] 具体星期写进 prompt（「周一、周三、周五，共 3 天」），并要求 `meta.daysPerWeek` 与训练日数一致
- [ ] 重点部位只做倾向，不突破 18 个 catalogId 白名单；库内没有的动作仍走 `custom_`
- [ ] `AIPlanGenerating` 改签名；`AIGenerateCard` 传 brief；「复制提示词」同一条路径
- [ ] `AIPlanInterpreter.interpret(text, memory:, exercises:)` 在 client 里传真实值，修掉 AI 路径无视别名记忆 / 我的动作
- [ ] 测试：brief 覆盖四项、伤病不被移除、无 brief 时输出与旧版逐字一致、原话截断、copyable 与 messages 同源
