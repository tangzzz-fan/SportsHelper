# 14: 训练记录持久化（SwiftData）

**What to build:** 完成一组就落盘，杀掉 App 再打开，记录与本周进度还在。今日屏与记录屏读同一份数据，不再各自写死。

**Blocked by:** 13

**Status:** done（2026-10-22）

- [x] `SessionEntity`（@Model）+ `SessionStore`（@Observable，fetch/upsert/reload）
- [x] 每完成一组 upsert 一次；结束训练写 finishedAt
- [x] 本周次数、连续天数、完成率由 Core 纯函数 `HistoryStats` 计算（8 条测试）
- [x] 今日屏与记录屏共用同一个 store，不再出现「今日 2/3、记录 0/3」
- [x] 记录屏空态
- [x] 端到端验证：卸载重装 → 种子写入 → 杀进程 → 不带种子重启，记录仍在
      （shots/t14-history-persisted.png）
- [ ] 与 SPEC §6 的 SetLogRecord / PlanRecord 表尚未建（本轮只落会话级汇总），
      组级明细留待下次迭代
