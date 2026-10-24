# SportsHelper 项目长期记忆

## 测试范围（2026-10-24 用户明确要求）

**UI 测试默认不跑**——一轮 6 分钟。日常只跑单测，UI 显式 `--with-ui` 才跑：

- `ui`（动了 `DongKe/`、`Shared/`、`DongKeUITests/`、`project.yml`、`DongKe.xcodeproj/`）→ `--run` 只跑单测 487 条，`--with-ui` 追加 UI 16 条
- `core`（只动 `DongKeCore/`、`DongKeCoreTests/`、`Tools/`）→ 只跑单测
- `none`（纯文档）→ 都不跑，仍要过 ARCHITECTURE §4.3 门禁

该补跑 UI 的四个节点：提交前动过视图 / 改了命中区 / 改了播报或语音输入 / 要上真机。细则见 `docs/HANDOFF.md` §6.21。

## 按钮命中区（2026-10-24）

`Text` 的命中区只有字形，`frame(maxWidth:)` 与 `background` 都**不扩大**可点范围，必须 `.contentShape(Rectangle())`。统一在 `PressableGlassStyle` 里加，新按钮不要直接用 `.buttonStyle(.plain)` 配 `Text` + `frame`。

查同类问题别按视图结构扫遮挡（会把按钮内 `Text`、祖先容器全算成遮挡，误报一堆），直接量 `element.frame` 对比视觉尺寸。UI 测试断言行为、不断言结构。见 §6.22。

## 播报文案口径（2026-10-24）

- 「组」只在两个尺度出现：开始语是全天总量，每组是**该动作的累计**序号，同一句不混用
- 动作名前置：`俯卧撑，第 2 组，共 3 组，10 次`
- 跨区块休息报**下一个动作**，不是区块名
- 循环 / 超级组的累计口径在 `WorkoutFlowModel.setCounts`，UI 与播报共用

改文案后必跑 `scripts/voice-dump.sh` 复核三种（现四种）计划形态。见 §6.23。

## 动作图示（2026-10-24 定稿）

- 图是**矢量 path**（`DongKeCore/Figure/GeneratedFigureData.swift`，3MB，别手改），不是 GIF。31 个动作 × 3 帧 + `_generic` 占位。
- 素材 = bryllim/workout-guide（302 个，906 帧，CC BY-SA 4.0），**上游是 Everkinetic**。根目录 `everkinetic-data/` 是同一脉的 raster 版（277 个），已在 `.gitignore`，**不是更大的库**。
- 「同风格」有量化判据：线宽/图高 **0.67%–2.90%**（中位 1.23）、墨量 **3%–8%**（中位 5.4）、宽高比 0.87、留白 4.5%、图高 433–470 单位 / 512 画布。
- **取景也要同档**：上游颈部那两张是胸像特写（图高 138），190pt 并排就是另一个档位，不能用。
- 判定「能不能接」= 语义对 + 取景同档 + 有矢量源。缺一条就走占位，不用近似素材。
- 生成器 `.scratch/figure-and-glass/tools/gen_figures.py`（手动跑，不进构建）；`svgcmd.py` 已支持 `A` 弧线 flag 连写。
- 参数化自绘（`Tools/FigureDraw/`）三代都收敛到「木偶」，已判死，别再试。

## 环境

- 模拟器 UDID：`D16A8318-973E-45CE-936B-94F5FFE3E0EC`（iPhone 18 Pro），`content_size` 保持 `large`，不要设 AX3
- 推 origin 需代理：`git -c core.sshCommand="ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'" push origin main`
- `ios-run.sh` 会误判 UI 套件收尾，跑 UI 直接用 `xcodebuild ... -only-testing:DongKeUITests test`

## 跑测试：必须 Python 包一层（2026-10-24）

`xcodebuild test` 跑完**不退出**，无限刷 `IDESchemeActionSDKRecord ... invalidDigitCount(94232)`（Xcode 27 解 5 位 build 号失败），测试其实几秒就跑完。

固定三步，见 `docs/HANDOFF.md` §6.25：

1. `build-for-testing`（正常退出）
2. Python `subprocess.Popen` + `wait(timeout=90)` 跑 `test-without-building`，超时 `kill()`
3. 只认日志里 `Test run with` / `✘ Test "..." failed`，**不认退出码**

⚠️ macOS 没有 GNU `timeout`，写 `timeout 200 xcodebuild` 会 `command not found`，随后 grep 空输出会被误读成「通过」。同一套写法推广到 `xcrun simctl`、`devicectl`、`swift test` 等会挂住的长命令。
