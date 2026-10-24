# 02: PlanBrief 与本地解析器

**What to build:** 把「一句话」变成可确认的结构化约束，而不是直接塞进 prompt。纯 Core、无网络、可单测。

**Blocked by:** None (can start immediately)

**Status:** done（2026-10-24）

- [x] `PlanBrief`：`sentence` / `weekdays: [Weekday]?` / `daysPerWeek: Int?` / `sessionMinutes: Int?` / `equipment: [Equipment]?` / `goal: PlanGoal?` / `focus: [String]` / `avoid: [String]` / `unparsed: [String]` / `isVague`
- [x] `PlanBrief.resolved(against:)`：没说的字段回落档案；具体星期优先于笼统天数；只给天数时按档案星期补齐；`maxExercises` / `maxSets` 跟着本次时长走
- [x] `PlanBriefParser.parse(_:)` 复用 `TextNormalization`（全角 / 汉字数字 / 繁简），星期用独立解析器而不是复用 `DraftLineScanner.weekday(in:)`——后者只取第一个，且会把「每周三天」读成周三
- [x] 解析范围：星期（周一 / 一三五 / 周一、三、五 / 每周一三五 / 周末）、频率（三天 / 每周三次 / 一周三练 / 天天）、时长（半小时 / 一个半小时 / 1.5 小时 / 20–30 分钟）、器械（哑铃 / 弹力带 / 壶铃 / 卧凳 / 徒手 / 没器械 / 不去健身房）、目标（减脂 / 增肌 / 耐力 / 体能 / 拉伸）、重点部位、临时避开（膝盖不好 / 腰疼 / 别跳 / 不要深蹲）
- [x] 明确不猜：没说的字段留 nil；「随便 / 你定 / 看着办」标 `isVague`；「隔天」不硬换算，写进 `unparsed` 让用户选
- [x] 护栏：原话 >200 字截断并记 `unparsed`；天数 1…7、时长 5…120 分钟，越界丢弃并记入 `unparsed`；杠铃 / 跑步机不在可选器械里就明说，不偷换
- [x] 测试 36 条：每种表达、混合长句、繁体、全角数字、冲突、越界、含糊、空输入

**两个坑**：

1. `每周三天` / `每周三练` / `一周三次` 里的「周三」不是星期三。做法是先把「每/一 + 周 + 单个数字 + 天/次/练」从星期文本里剔掉，再解析星期；`周一三五练` 不能剔，因为它是一串具体星期。
2. `天天练` 会被「连续两个天=周日」误吃，所以星期解析前也要剔掉「每天/天天」。

**边界**：解析器不做动作级映射（「练手臂」不等于某个 catalogId），只产出意图，交给 prompt 与模型在 18 个白名单内近似。
