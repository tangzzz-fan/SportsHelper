# 23: 别名记忆（改一次，以后不用再改）

**What to build:** 用户在校对页把「壶铃摆动」指到某个库内动作之后，记住这条对应关系。下次导入同一份计划（或同一个 AI 写的同一动作）时先用记忆，不再走「不在库里」，并在假设卡片里说明「按你上次的选择」。

**Blocked by:** 22

**Status:** done（2026-10-23）

- [x] `AliasMemory`（值类型，`[归一化名: catalogId]`，`remember` / `catalogId(for:)` / `merged(with:)` / `pairs`）
- [x] 解析链接受记忆：`PlanImportService.parse(_:memory:)` → `PlanDraftParser` → 表格 / 行扫描 / JSON 三个适配器
- [x] 记忆优先于别名表，且**优先于 `forcedId`**（一行多动作时 `forcedId` 曾经压过记忆，已改）
- [x] 记忆命中时不再标「猜测」——用户已经选过，就不该再当成猜的
- [x] `AliasMemoStore`（`UserDefaults` 键 `dk.alias.memo`，存 `[String: String]`）；不进 SwiftData：丢了只是重问一次，不值得一次 schema 变更
- [x] 校对页：改动作后 `remember(原文名, catalogId)`；「应用」时若原本是猜测行，也算一次确认
- [x] 假设卡片写明「「X」按你上次的选择记为「Y」」
- [x] 测试 5 条：记忆优先于猜测、未命中回退别名表、归一化（空格/大小写）、同名覆盖、合并取新

**边界**：记忆在「一行里多个动作」的切分阶段不参与（切分只认别名表），但每个动作块解析时会先查记忆，所以结论仍然正确；只有「整行没有别名可切」的情况才依赖别名表。
