# 22: 修饰词否决表（防止把「杠铃深蹲」静默当成自重深蹲）

**What to build:** 别名表命中后，再检查原文里有没有「库内动作覆盖不到的限定词」。有就把这次匹配标成「猜的」：动作仍然照常计入（不打断导入），但在校对页把原文名摆出来、把猜测目标明写出来，让用户一眼看见并被要求确认。

**Blocked by:** 无

**Status:** done（2026-10-23）

- [x] `ExerciseAliasResolver.match(for:memory:)` 返回 `ExerciseMatch`（catalogId / 命中的别名 / modifier / source）；`catalogId(for:)` 退化成薄壳
- [x] 敏感修饰词四族：器械（杠铃/哑铃/壶铃/绳索/弹力带/拉力器/史密斯/器械/负重/沙袋/药球/瑞士球/波速球）、变式（箱式/相扑/上斜/下斜/窄距/宽距/高位/低位/跳箱/跳跃/爆发/离心/暂停/半程/靠墙）、单侧（单臂/单腿/单手）、保加利亚
- [x] 判定 = 原文含修饰词 **且** 命中的别名不含该词（`哑铃划船` 精确命中自己不拦；`单手哑铃划船` 拦）
- [x] `DraftItem.reviewModifier` / `usedMemory`；三个适配器都走 `match(for:)`
- [x] `CompiledDraft.guessedItems[itemId] = GuessedRow(originalName, catalogName, modifier)`
- [x] `ParsedPlanDraft.guessedItems`，`PlanImportService` 透传
- [x] 校对页：标题显示原文名，橙色徽标「按深蹲计入」，点开可改；假设卡片只留一条（不再和「按 X 处理」重复）
- [x] 测试 8 条：器械/变式/单侧被标、别名自带修饰词不标、端到端 guessedItems、一行两动作只标带限定词的那个

**过程中挖出来的三个真问题**（都修了）：

1. **别名表有两份**：`ExerciseAliasResolver.table`（私有，80 条）和 `DraftLineScanner.aliasTable`（36 条），改一边不生效于另一边。合并成 `ExerciseAliasResolver.aliases` 单一来源，行扫描改为读它。
2. **一行多动作时，第一个动作前面的修饰词被切掉**：切块起点取的是别名范围起点，`杠铃深蹲 4×8，臀桥 3×12` 的第一块从「深蹲」开始，「杠铃」直接丢掉——正是本票要防的事。加了 `trailingModifierStart(in:)` 往前回看紧邻的修饰词。
3. **`cleanedName` 不认重量单位**：`杠铃深蹲 5×5 100kg` 的名字会残留 `kg`。补了 `\d+\s*(kg|kgs|lbs?|pounds?|公斤|千克|磅)` 的剥离。
