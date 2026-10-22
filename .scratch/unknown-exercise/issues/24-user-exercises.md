# 24: 我的动作（库外动作可以沉淀下来）

**What to build:** 校对页遇到库外动作时，除了「换成库内动作」，还能「存为我的动作」。存下来的动作进动作库的独立分区，下次导入同一个动作可以直接指过去，练的时候也能在库里翻到。

**Blocked by:** 23

**Status:** done（2026-10-23）

**边界（重要）**：内置动作库仍然 18 个，`ExerciseLibrary` 一行不改。我的动作是叠加层，id 一律 `custom_<slug>`，不参与 `ExerciseLibrary.entry(for:)` 的查找。

- [x] Core：`CustomExerciseId.slug/id`——**唯一**的 slug 生成处，`PlanDraftCompiler` 也改用它（原来各写一份）
- [x] Core：`UserExercise` + `UserExerciseCatalog`（按 id / 按归一化名字查、同名去重、加/删）
- [x] Core：`PlanDraftCompiler.compile(_:exercises:)`——命中我的动作就指向它的 id、缺组数/次数/休息按它的默认值补，并不再写进 `unmappedNames`
- [x] App：`UserExerciseEntity` + `UserExerciseStore`（SwiftData，跟 Plan/Profile 同一个容器；主键 `exerciseId`）
- [x] 校对页弹层：库外动作才有「存为我的动作」开关，打开后可选分组；应用时写入并记住映射
- [x] 动作库页底部「我的动作」分区 + 详情页（`_generic` 图示、默认剂量、删除）
- [x] 校对页 Picker 增「我的动作」分组
- [x] 徽标三分：内置库（无）/ 我的动作（青）/ 不在库里（橙）；猜测行另算
- [x] 测试 3 条：slug 稳定、目录查重与删除、编译器用我的动作补剂量

**过程中的三个坑**：

1. **`Equipment` 只有四类**（徒手/哑铃/弹力带/壶铃），杠铃和器械表达不了。不新造 case（那会牵动引导问卷），我的动作只显示分组，不声称装备；`inferEquipment` 也只认哑铃/壶铃/弹力带，其余存徒手。
2. **`_generic` 兜底是实心剪影**，和 19 张单色线条插画放一起像块黑斑（第一版截图就是）。渲染时对 `_generic` 降到 0.16 透明度，当"占位"而不是"这是这个动作"。
3. **SwiftData 的 `#Predicate` 不能捕获结构体属性**（`exercise.id` 会被当成 KeyPath 求值报错），先取局部 `let targetId = exercise.id`。

**已知未做**：

- 我的动作不参与"这一行是不是动作"的判断：`周一 壶铃摆动`（没有任何剂量）仍会被当成标题丢掉，因为行扫描只认别名表。要修得把目录注入扫描器，留到有需要时。
- 我的动作不生成图示，也不编造要点——用通用占位，页面里已写明。
- 距离型目标（"40 米"）仍然丢失，和 ticket 21 的遗留项同源。
