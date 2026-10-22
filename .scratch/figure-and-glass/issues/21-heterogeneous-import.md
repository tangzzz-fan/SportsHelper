# 21: 异构训练计划拆解（适配器链 + 容错中间层）

**What to build:** 不管对方是哪个 agent、输出哪种形状，都能拆成可校对的结构化计划：schema JSON、任意 JSON、Markdown 表格、列表、散文；动作名走别名表归一到 18 个动作，归不上的保留原名；每一处补默认值都写成「假设」摆在校对页。

**Blocked by:** 20

**Status:** done（2026-10-22）

- [x] `PlanDraft` 容错中间层：`DraftDay` / `DraftItem`（rawName、catalogId 可空、sets/value/targetType/rest 可空、perSide、assumptions、origin）
- [x] 适配器链 `PlanDraftParser`：表格优先（含 `|` 时）→ 行扫描；JSON 走 `DraftJSONAdapter`
- [x] `DraftJSONAdapter`：键名别名（name/exercise/动作、sets/组数、reps/次数、durationSec/秒、restSec/休息）、weeks→days 嵌套、blocks 递归展开、字符串剂量（"3组"/"12次"/"45s"/"8-12"）
- [x] `DraftTableAdapter`：按表头定位列（动作/组数/次数/休息），列顺序打乱也不错位；`#` 标题行进 day 上下文
- [x] `DraftLineScanner`：列表标记、`###` 标题、Day N、多日散文（先按星期切行再按句号切句）、循环轮次、每侧、注意事项单独收集
- [x] `ExerciseAliasResolver`：约 60 条中英别名，最长匹配优先（侧平板支撑 > 平板支撑），英文按词边界
- [x] `PlanDraftCompiler`：weekday 分配（没写就顺排并说明）、缺剂量按 3 组 / 12 次 / 60 秒补、静力动作无时长按 30 秒、同日合并、超 7 天截断
- [x] `ParsedPlanDraft` 增 `assumptions` / `unmappedNames`；校对页顶部「我替你判断了这些」卡片 + 行内「不在库里」徽标
- [x] 校对行可换成库内动作（`PlanEditing` 支持改 catalogId，静力动作自动切时长）
- [x] 发布给 AI 的提示词模板 `PlanPromptTemplate`，粘贴页一键复制；**提示词里的示例 JSON 由测试保证能被自己的解析器读懂**
- [x] 10 条新测试：5 类真实 agent 形状 + 默认值 + 别名 + 同日合并 + 未识别保留 + 提示词契约
- [ ] 未做：距离型目标（"40 米"）、AMRAP / RPE 之类强度记号；归不上时只保留原名，不猜动作
