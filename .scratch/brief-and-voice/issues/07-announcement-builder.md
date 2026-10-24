# 07: 播报文案生成器

**What to build:** 训练流程里每个该说话的节点，生成一句短、准、不啰嗦的中文。纯函数，先测后用。

**Blocked by:** None (can start immediately)

**Status:** todo

- [ ] `WorkoutAnnouncement`：sessionStart / setStart / restStart / restCountdown / restFinished / blockBreak / finished
- [ ] `WorkoutAnnouncementBuilder`：动作名、第 N 组 / 共 M 组、剂量（12 次 / 45 秒 / 每侧 10 次 / 40 米）、休息时长、下一动作
- [ ] 读法规则：>60 秒休息读「1 分 30 秒」；倒数只读「3 / 2 / 1」；完成读「完成 9 组，完成率 100%」
- [ ] 长度护栏：单句 ≤40 字；超长砍动作要点，不砍动作名与剂量
- [ ] 测试 ≥20 条：四种目标类型、每侧、循环 / 超级组、最后一组不说「下一组」、休息 0 秒不播、完成率 0 / 100
