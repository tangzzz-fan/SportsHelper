# SportsHelper 项目长期记忆

## 文件长度上限 500 行（2026-10-25 董事长改，原 300）

**不含空行**，按 `grep -cve '^[[:space:]]*$'` 统计。门禁扫 `DongKe/ DongKeCore/ DongKeCoreTests/ DongKeUITests/ Shared/` 五个目录：

```bash
for f in $(find DongKe DongKeCore DongKeCoreTests DongKeUITests Shared -name '*.swift'); do n=$(grep -cve '^[[:space:]]*$' "$f"); [ "$n" -gt 500 ] && echo "$n $f"; done
```

改了这条要同步三处：ARCHITECTURE §4.3-1、§4.3 门禁段、Feature 完成判据表；SPEC §4 与 §10。

**已拆开的文件不回并**——按职责边界切的，不是为凑行数。上传上限放宽不等于鼓励写大文件：单文件仍应一个主职责。

## 跟练类内容（五禽戏 / 八段锦 / 太极）不是动作库扩容（2026-10-25）

用户说「我想跟着练五禽戏」时，**现有链路会静默给一份深蹲计划**：`focus`/`goal`/`weekdays` 全落空，`unparsed` 不记未知名词，`isVague` 只认「随便/你定/都行」，确认页因此什么都不提示。这是「做了别的还不说」，比不支持更伤信任。

三条规矩：

1. **不要塞进 `WorkoutPlan`**。单组动作会被播报念成「第 1 组，共 1 组」，10 个动作进 `SetLog` 会弄脏完成率/降阶率口径——那是相对 GymMane 唯一的硬差异点。
2. **真做跟练要新类型 `Routine`**（段序列：名称/时长/口令），复用计时器与 `endAt` 回前台重算，但不接 `WorkoutFlowModel`，不进统计分母。
3. **五禽戏不是一套动作**：国家体育总局版 10 式 / 华佗非遗版（流派各异，刘时荣一路 40 式）/ 少林版。做之前必须指定唯一标准答案。

决策与触发条件见 `.scratch/follow-along/issues/01-跟练分路的决策.md`、backlog §7。

## 测试范围（2026-10-24 用户明确要求）

**UI 测试默认不跑**——一轮 6 分钟。日常只跑单测，UI 显式 `--with-ui` 才跑：

- `ui`（动了 `DongKe/`、`Shared/`、`DongKeUITests/`、`project.yml`、`DongKe.xcodeproj/`）→ `--run` 只跑单测 539 条，`--with-ui` 追加 UI 21 条
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

## 动作库扩容：只有三处要手工同步（2026-10-24）

库已 43 条。**加动作只需动三处**，第四处已改成派生：

1. `DongKeCore/Models/ExerciseCatalog{Lower,Upper,Core}.swift` —— `cues` ≥2、`mistakes` ≥1、`regressionName` 非空
2. `ExerciseAliasResolver.aliases` —— 每动作 ≥3 个叫法，且**自己的名字要能认出自己**（`ExerciseNounTests` 会查）
3. `gen_figures.py` 的 `MAPPING` + `FigureLibraryTests.records` 数字（= MAPPING + 1）

**`PlanCatalog.items` 不用动**：2026-10-24 已改成从 `ExerciseLibrary` 派生（`purposes` 含 `.strength` 进池、`isDynamic` 取 `.warmup`）。在此之前它是第二份手工清单，18→39 那轮漏改，21 条动作对本地生成器完全不可见且无测试会红。见 HANDOFF §6.28。

**`regressionId` ≠ 换动作**。降阶是「同一动作更轻」（深蹲→靠墙静蹲，都压膝），换动作是完全绕开部位，用 `alternativeId`。口径在 ARCHITECTURE §5.6。

**器械示意与 `equipment` 不一致时改文字不改图**（臀推用杠铃版素材、蚌式素材带弹力带），前提是动作模式没变。

**康复类动作要同时满足三条**，缺一条就出错：`affectedParts: []`（标了部位会被自己的警告标红）、`relievedParts`（否则校对页不推荐）、`purposes` 不含 `.strength`（否则被排进训练主项，`PlanCatalog` 的入选条件就是这条）。`PlanSafetyChecker.reliefs` 另有一条运行时约束：推荐的动作与不适部位必须不相交。

## 动作图示（2026-10-24 定稿）

- 图是**矢量 path**（`DongKeCore/Figure/GeneratedFigureData.swift`，3MB，别手改），不是 GIF。35 个动作 × 3 帧 + `_generic` 占位。
- 素材 = bryllim/workout-guide（302 个，906 帧，CC BY-SA 4.0），**上游是 Everkinetic**。根目录 `everkinetic-data/` 是同一脉的 raster 版（277 个），已在 `.gitignore`，**不是更大的库**。
- 「同风格」有量化判据：线宽/图高 **0.67%–2.90%**（中位 1.23）、墨量 **3%–8%**（中位 5.4）、宽高比 0.87、留白 4.5%、图高 433–470 单位 / 512 画布。**宽高比 0.87 是站姿口径**，躺姿动作本来就在 2.0 上下（`glute_bridge` 2.10），别拿一个数卡所有。
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
