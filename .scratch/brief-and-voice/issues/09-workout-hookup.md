# 09: 挂到训练流程

**What to build:** 开始、每组、休息、最后 3 秒、归零、换动作、完成，各说一句，且只说一次。

**Blocked by:** 07, 08

**Status:** todo

- [ ] `WorkoutVoiceCoordinator` 观察 `stepIndex` / `rest` / `restFinishedToken`，映射到 announcement
- [ ] 倒数门：休息剩 3 / 2 / 1 秒各播一次（0.25s tick 下不重复），暂停不播，+15s 后重新计
- [ ] 首进训练页一次性提示「打开语音提示？」（`dk.voice.prompted`），拒绝后不再问
- [ ] 开关关闭时零开销（不建 synthesizer、不占 audio session）
- [ ] 测试：整条 2 组流程的事件序列、重复渲染不重播、跳过组不播下一组、总结页静音
- [ ] UI 测试：`DK_VOICE_ENABLED=1` + 假 speaker，断言首组开始时有一条播报记录（DEBUG 日志标签）
