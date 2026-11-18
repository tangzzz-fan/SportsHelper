# 02: SetLog 记重量

**What to build:** 用户在训练页能看到并调整当前组的重量；做完一组，重量连同次数一起落库；杀掉 App 重进，「上次」显示的仍是那个重量。

**Blocked by:** None (can start immediately)

**状态：** 已落地（2026-11-18）。829 条单测全绿（新增 5 条编解码 + 6 条文案），变异验证一次（把 `self.actualLoad = actualLoad` 改成 `nil`，两条红）。

- [x] `SetLog` 新增 `actualLoad: Load?`；nil 表示「按处方」，与 `planDate` 的回落同构
- [x] `SetLogEntity` 新增 `actualLoadValue` / `actualLoadTypeRaw`，扁平存储；旧数据读出为 nil，映射层按处方重量处理
- [x] 训练页当前组的次数旁显示重量；`load.type == .bodyweight` 且 0kg 与 `targetType` 为秒 / 米的动作不显示
- [x] 用户不动重量时，落库的 `actualLoad` 保持 nil（不写 0），避免把「没改」记成「0kg」
- [x] 重量调节步进固定 2.5kg，按 `itemId` 记忆——同一动作下一组沿用，换动作回到它自己的处方
- [x] 文案抽到 `ExercisePrescription.workoutDoseLine(load:)`，单测覆盖自重 / 负重 / 单侧 / 静止 / 弹力带 6 种
- [x] 模拟器：旧包建库 → 新包覆盖安装不崩；`PRAGMA table_info(ZSETLOGENTITY)` 已出现 `ZACTUALLOADVALUE`（FLOAT）与 `ZACTUALLOADTYPERAW`（VARCHAR）
- [ ] **未验**：真实完成一组 8kg 后杀掉重进，训练页的「上次」是否带重量。模拟器无法自动化点击，等第一次真机走查补上
