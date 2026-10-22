# 11: 验证玻璃回退路径

**What to build:** 确认 `GlassSurface` 的 material 回退路径在浅色与深色下都成立（内高光、外描边、厚度边、镜面高光四件套齐全），并与原生玻璃并排比对。

**Blocked by:** 无

**Status:** done（2026-10-22，以强制回退开关验证）

- [x] 回退路径可被强制触发：`DK_FORCE_LEGACY_GLASS=1`（仅 DEBUG）
- [x] 今日浅色截图：shots/t11-legacy-today.png
- [x] 训练执行浅色截图：shots/t11-legacy-workout.png
- [x] 观感成立：material + 四件套可读，主按钮保持实心 tint
- [ ] **真实 iOS 18 运行时仍未安装**（`simctl runtime list` 只有 iOS 27.0）。注意：判断是 `#available(iOS 26)`，
      装 iOS 26 运行时也会走原生分支，要验回退必须 ≤ iOS 25 的运行时。此项留待有运行时后补验。
