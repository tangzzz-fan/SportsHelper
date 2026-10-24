# 09: 挂到训练流程

**What to build:** 开始、每组、休息、最后 3 秒、归零、换动作、完成，各说一句，且只说一次。

**Blocked by:** 07, 08

**Status:** done（2026-10-24）

- [x] `WorkoutVoiceSession`（Core）收 `stepChanged` / `restStarted` / `restTick` / `restFinished` / `finished` / `stop`，逐个映射到 announcement
- [x] 倒数门：只在剩 3 / 2 / 1 秒各播一次（0.25s tick 下靠 `lastCountdown` 去重）；暂停不播（`rest` 不是 `.running` 就不 tick）；`restStarted` 重置倒数，+15 秒后会重新从 3 报
- [x] 重复渲染不重播：`lastStepIndex` 去重
- [x] 跳过组不播下一组：`advance(silent:)`
- [x] 总结页静音：`workoutBody` 的 `onDisappear` → `stop()`；`showsSummary` 时 `onAppear` 直接不启动
- [x] 进后台 / 关开关立刻停：`SpeechCuePolicy` 由 `scenePhase` 与设置开关驱动
- [x] 开关关闭零开销：`startVoiceIfNeeded` 先看开关，没开就不建 coordinator、不建 synthesizer、不碰 audio session
- [x] 测试：`WorkoutVoiceSessionTests` 15 条（含整条两组流程的播报序列、重复 tick、跳过、完成后再播报被忽略）
- [x] 端到端：`DK_VOICE_ENABLED=1 DK_VOICE_FAKE=1 DK_PREVIEW=workout` → App 内真实跑出 `开始训练，居家减脂 · 4 周，共 9 组` / `第 1 组，共 3 组，俯卧撑，10 次`

**挂钩放在 `WorkoutSession` 而不是视图**：`advance()` / `startRest()` / `refresh()` / `finish()` 四个点覆盖按钮、通知深链、断点续练三条入口；放在 `WorkoutView` 的 `onChange` 里会漏掉通知触发的那些调用。

**两个坑**：

1. **`onAppear` 时 App 还没 active**，`UIApplication.shared.applicationState` 不是 `.active`，闸门会把「开始训练」整句吞掉（第一次端到端就是这样零日志）。现在 `activeCoordinator()` 显式按 `isForeground: true` 起步，之后由 `scenePhase` 纠正。
2. **同一动作的连续组不要重复报名**：`第 1 组…俯卧撑，10 次，下一个：俯卧撑` 很蠢。`nextName` 与当前动作同名时置 nil。

**没做**：首进训练页的「打开语音提示？」引导弹窗。默认关 + 设置页开关已经够，弹窗会打断「打开就开始」；等有真实使用反馈再决定。《`dk.voice.prompted` 因此也没写。》

**UI 测试改成端到端日志**：`DK_VOICE_FAKE=1` 时假 speaker 把每句写进 App 沙盒 `tmp/dk-voice.log`，`xcrun simctl get_app_container … data` 就能读到，比在训练页塞一条测试专用 UI 更干净，也不会影响既有 AX 布局断言。
