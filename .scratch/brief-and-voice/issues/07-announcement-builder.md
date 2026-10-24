# 07: 播报文案生成器

**What to build:** 训练流程里每个该说话的节点，生成一句短、准、不啰嗦的中文。纯函数，先测后用。

**Blocked by:** None (can start immediately)

**Status:** done（2026-10-24）

- [x] `WorkoutAnnouncement`：sessionStart / setStart / restStart / restCountdown / restFinished / blockBreak / finished，每种都有 `text`
- [x] `WorkoutAnnouncementBuilder`：从 `WorkoutPlan` + `dayIndex` 建表（动作名、每组总数、剂量），按 `FlowStep` 索引取文案
- [x] 读法规则：≥60 秒读「1 分钟 / 1 分 30 秒」；倒数只读 3 / 2 / 1；完成读「完成 9 组，完成率 100%」
- [x] 长度护栏：单句 ≤40 字；超长按「下一个 → 共 N 组」的顺序丢可选片段，动作名与剂量最后才动
- [x] 测试 24 条：四种剂量、每侧、公里、循环 / 超集、最后一组无「下一个」、休息 0 秒不播、完成率 0 / 56 / 100、长名字降级、全流程每句 ≤40 字

**两处实现取舍**：

1. **剂量不复用 `SetTarget.doseText`，另写 `WorkoutAnnouncementBuilder.doseText`**。界面那份是「10 次/侧」，念出来是「10 次斜杠侧」；播报要「每侧 10 次」。两份各自服务读者，不合并。
2. **60 秒读「1 分钟」而不是「60 秒」**。原票只写了「>60 秒读 1 分 30 秒」，没说 60 本身；念「1 分钟」更自然，测试按这个锁。

**边界**：文案不念动作要点与常见错误——念出来一句就超 40 字，那些留在屏幕上由 VoiceOver 读。打断 / 中止策略归 08。
