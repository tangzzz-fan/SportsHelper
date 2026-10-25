# 会话账本与「今天再加一组」

口径已定，账本、加组入口、断点续练、三处可见数字与静态减量轴都已落。**唯一没做的是静态动作的强证据**（UI 不记录超时秒数）。

## 已定口径（ADR-0006）

| 问题 | 结论 |
|---|---|
| 加组进不进完成率分母 | **不进**。分母锁进入训练时的计划组数；跳过一组再加两组，仍是 11/12 |
| 加组能不能让「这一节练过没有」成立 | **不能**。`HistoryStats.isCompleted` 只认计划内完成 |
| 额外组算不算剂量 | **算**。进本周有效组与肌群分布，但带 `origin = .extra`，可单独数 |
| 静态动作的余力 | 保持时间 +5 秒/档，上限 60 秒；到顶沉默，不转成加组 |

## 已落地

- `SetLog.origin`（`prescribed` / `extra`），旧 checkpoint 缺字段或未知值都回落计划内。
- `SessionLedger`：会话计数的唯一出处，按 `origin` 分账、按 `(sessionId, prescriptionId, setIndex, origin)` 去重。
- `SessionRecap` 改为账本投影；`WorkoutSession.completedSets` / `progress` / `recap` 全部从账本取数。
- `SetLogEntity.originRaw` 可选列；`SetLogStore` 读写来源。
- `DoseReport.extraSets`；`effectiveSets` 含额外组，`completedSets` / `skips` 只数计划内。
- `ProgressionAxis` + `PlanProposal.Change.Field.hold`；静态动作余力进阶（+5 秒），疼减 20% 取整到 5 秒、太累 −5 秒。
- 休息页「今天再加一组」：`WorkoutSession.script` 插入 `.set`，一节课最多 3 组，可撤销。
- 断点续练：`WorkoutCheckpoint.steps` 直接存脚本，旧断点没有这个字段就回落到计划展开。
- 结束页 / 记录页 / 播报补「额外 N 组」；播报用独立 case，完成率仍按计划组数。

## 验收缺口

- **加组按钮没在模拟器上手动点过。** 单测覆盖了脚本插入、checkpoint 往返、账本口径与播报文案；休息页的布局与点击链路需要手动走一遍。
- **SwiftData 旧库覆盖安装没验。** `originRaw` 是可选列，按轻量迁移处理。

## 刻意不做

- 不把加组写回计划（ADR-0004：当场加的是训练量，不是处方）。
- 不做「补练昨天欠的组」——那是排期偏移，属于 BACKLOG §14 的另一件事。
- 不按肌群拆分母。分母只有一个：计划组数。
- 静态动作的**强证据**还没开：UI 不记录「多撑了几秒」，`clearedEverySet` 对静态没有可用数据。见 BACKLOG §1 文末。
