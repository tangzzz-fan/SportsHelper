# 02: PlanBrief 与本地解析器

**What to build:** 把「一句话」变成可确认的结构化约束，而不是直接塞进 prompt。纯 Core、无网络、可单测。

**Blocked by:** None (can start immediately)

**Status:** todo

- [ ] `PlanBrief`：`sentence` / `weekdays: [Weekday]?` / `daysPerWeek: Int?` / `sessionMinutes: Int?` / `equipment: [Equipment]?` / `goal: PlanGoal?` / `focus: [String]` / `avoid: [String]` / `unparsed: String`
- [ ] `PlanBrief.effective(with:)`：没说的字段回落档案；`daysPerWeek` 与 `weekdays` 冲突时以具体星期为准；只给天数时按档案星期顺序补齐
- [ ] `PlanBriefParser.parse(_:)` 复用 `TextNormalization`（全角 / 汉字数字）与 `DraftLineScanner.weekday(in:)`
- [ ] 解析范围：星期（周一 / 一三五 / 每周一三五 / 周末 / 隔天）、频率（三天 / 每周三次 / 天天）、时长（半小时 / 30 分钟 / 一小时）、器械（哑铃 / 一对哑铃 / 弹力带 / 壶铃 / 卧凳 / 徒手 / 没器械）、目标（减脂 / 增肌 / 耐力 / 体能 / 拉伸）、重点部位、临时避开（膝盖不好 / 腰疼 / 别跳 / 不要深蹲）、否定（不想去健身房）
- [ ] 明确不猜：没说的字段留 nil；「随便 / 你定 / 看着办」返回空 brief 并标 `isVague`
- [ ] 护栏：原话 >200 字截断并记 `unparsed`；天数 1…7、时长 5…120 分钟，越界丢弃并记入 `unparsed`
- [ ] 测试 ≥30 条：每种表达、混合长句、繁体、全角数字、冲突、越界、空 / 含糊

**边界**：解析器不做动作级映射（「练手臂」不等于某个 catalogId），只产出意图，交给 prompt 与模型在 18 个白名单内近似。
