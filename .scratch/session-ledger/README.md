# 会话账本与「今天再加一组」

口径已定，账本已落，**加组的入口与流程还没做**。这张看板只放剩下的部分，避免下次重新推一遍口径。

## 已定口径（ADR-0006）

| 问题 | 结论 |
|---|---|
| 加组进不进完成率分母 | **不进**。分母锁进入训练时的计划组数；跳过一组再加两组，仍是 11/12 |
| 加组能不能让「这一节练过没有」成立 | **不能**。`HistoryStats.isCompleted` 只认计划内完成 |
| 额外组算不算剂量 | **算**。进本周有效组与肌群分布，但带 `origin = .extra`，可单独数 |
| 静态动作的余力 | 保持时间 +5 秒/档，上限 60 秒；到顶沉默，不转成加组 |

## 已落地（本轮）

- `SetLog.origin`（`prescribed` / `extra`），旧 checkpoint 缺字段或未知值都回落计划内。
- `SessionLedger`：会话计数的唯一出处，按 `origin` 分账、按 `(sessionId, prescriptionId, setIndex, origin)` 去重。
- `SessionRecap` 改为账本投影；`WorkoutSession.completedSets` / `progress` / `recap` 全部从账本取数。
- `SetLogEntity.originRaw` 可选列；`SetLogStore` 读写来源。
- `DoseReport.extraSets`；`effectiveSets` 含额外组，`completedSets` / `skips` 只数计划内。
- `ProgressionAxis` + `PlanProposal.Change.Field.hold`；静态动作余力进阶与减量边界见 BACKLOG §1。

## 剩下的

- `01-今天再加一组.md`：入口、流程插入、断点续练重建。
- `02-播报与记录页.md`：摘要/记录页/播报补上额外组；不改口径，只补可见数字。

## 刻意不做

- 不把加组写回计划（ADR-0004：当场加的是训练量，不是处方）。
- 不做「补练昨天欠的组」——那是排期偏移，属于 BACKLOG §14 的另一件事。
- 不按肌群拆分母。分母只有一个：计划组数。
