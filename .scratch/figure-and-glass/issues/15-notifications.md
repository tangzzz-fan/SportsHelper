# 15: 训练提醒排程

**What to build:** 按计划的训练日排周重复提醒，提前 5/10/15 分钟可调；改设置后先清空旧提醒再重排，绝不叠加；单计划不超过 7 条。

**Blocked by:** 14

**Status:** done（2026-10-22）

- [x] Core `ReminderTrigger` 把一周星期映射到 `UNCalendarNotificationTrigger` 的 1=周日 约定（周一是 2，不是 1）；7 条测试守住这条与跨午夜提前
- [x] `ReminderPlanBuilder` 上限 7 条，休息日不产提醒，关闭开关产出 0 条
- [x] `NotificationService`：先按 `dk.plan.` 前缀清除旧请求再重排；权限状态与已排程条数可观测
- [x] 设置面板（今日页齿轮进入）：提醒开关、提前 5/10/15、权限状态、已排程条数
- [x] `ReminderSettings` 落 UserDefaults，重启后保持
- [x] 端到端验证：临时授权（provisional，无弹窗）下，设置面板显示「已允许 / 已排程 2 条」，
      与计划的两个训练日一致（shots/t15-settings-scheduled.png）
- [ ] 真实授权弹窗需人工点「允许」，模拟器无法预授权（`simctl privacy grant notifications` 被拒）
- [ ] 引导第 5 屏的权限请求时机尚未实现（目前从设置面板手动触发）
