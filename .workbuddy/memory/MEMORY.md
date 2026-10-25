# SportsHelper 项目长期记忆

## 文件长度上限 500 行（2026-10-25 董事长改，原 300）

**不含空行**，按 `grep -cve '^[[:space:]]*$'` 统计。门禁扫 `DongKe/ DongKeCore/ DongKeCoreTests/ Shared/` 四个目录：

```bash
for f in $(find DongKe DongKeCore DongKeCoreTests Shared -name '*.swift'); do n=$(grep -cve '^[[:space:]]*$' "$f"); [ "$n" -gt 500 ] && echo "$n $f"; done
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

## 测试范围：只有单测（2026-10-25 董事长改，取代 10-24 版）

**UI 测试全部取消**——目标、`DongKeUITests/` 目录（643 行 / 21 条）、`scripts/test-scope.sh` 一并删除。「取消」不是「默认不跑」：没有第二档了。

```bash
# 唯一命令：先 build-for-testing，再 Python 包一层跑 test-without-building
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'platform=iOS Simulator,id=D16A8318-973E-45CE-936B-94F5FFE3E0EC' \
  -derivedDataPath /tmp/dk-solo \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox' build-for-testing
```

**唯一的自动化验收 = 单测全绿。** 纯文档改动一档不跑，但仍要过 ARCHITECTURE §4.3 的 grep 门禁。

已知缺口写在明处：`DongKe/Services`（AI 客户端、语音、TTS）没有自动化兜底，改了就自己上模拟器点一遍那一个功能；命中区改完手动点一次边缘。

`Shared/A11yIdentifiers.swift` 保留——那是 VoiceOver 的词汇，不是 UI 测试的私产。

**恢复条件**（防止哪天又冒出来）：先答「给谁看、多久跑一次」；答不上来就别恢复。原文件在 `git log --diff-filter=D -- DongKeUITests` 那次提交里。细则见 `docs/HANDOFF.md` §6.6。

## 按钮命中区（2026-10-24）

`Text` 的命中区只有字形，`frame(maxWidth:)` 与 `background` 都**不扩大**可点范围，必须 `.contentShape(Rectangle())`。统一在 `PressableGlassStyle` 里加，新按钮不要直接用 `.buttonStyle(.plain)` 配 `Text` + `frame`。

查同类问题别按视图结构扫遮挡（会把按钮内 `Text`、祖先容器全算成遮挡，误报一堆），直接量 `element.frame` 对比视觉尺寸。UI 测试断言行为、不断言结构。见 §6.22。

## 播报文案口径（2026-10-24）

- 「组」只在两个尺度出现：开始语是全天总量，每组是**该动作的累计**序号，同一句不混用
- 动作名前置：`俯卧撑，第 2 组，共 3 组，10 次`
- 跨区块休息报**下一个动作**，不是区块名
- 循环 / 超级组的累计口径在 `WorkoutFlowModel.setCounts`，UI 与播报共用

改文案后必跑 `scripts/voice-dump.sh` 复核三种（现四种）计划形态。见 §6.23。

## 生成计划的日名口径（2026-10-25）

**一节课只做它名字说的那件事。** 三条一起才成立，别单独拆：

1. 专项日（下肢 / 上肢）不排另一组的动作。原来是 `main = 本组主力 + 另一组填充`，导致「上肢与核心」日里五分之三是腿。
2. 本组 `spread` 不满 3 个动作就不许叫这个名字（`minSpecializedItems`），按全身排、标题「全身循环」。纯自重上肢只有 `push_up`/`superman`，所以那一档没有上肢日；加卧凳（`bench_dip`）就恢复。
3. 全身日每组保底 2 个名额（`minSlotsPerGroup`），按各自肌群铺开。只做前两条时全身日会变成「四个下肢 + 一个俯卧撑」。

**不要用「加动作」消指标**：肩臂为 0 是「不计次要肌群」的必然；同理「臀 42」是纯自重池子填不满五天，改上限只会让下肢日没有腿（已试过，回退）。守卫 `PlanDayNamingTests` + `DoseBudgetTests`。见 BACKLOG §13。

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

## 文档分工：每个主题只有一个维护点（2026-10-25）

| 主题 | 唯一维护点 | 别处只许指过来 |
|---|---|---|
| 流程图 | `docs/FLOW.md` | 不重复画 |
| 结构与契约 | `docs/ARCHITECTURE.md` §4–§11 | — |
| 动作图示规格 | `docs/FIGURE-STYLE.md` | ARCHITECTURE §12 只留两条约束 |
| 动作库字段口径 | ARCHITECTURE §5.6 | — |
| 完成率 / 剂量口径 | ARCHITECTURE §11 + ADR-0006 | 别在视图里另算 |
| 术语 | `GLOSSARY.md` | — |

**ARCHITECTURE 会撒谎，别以为它记得住现状。** 2026-10-25 对齐过一次（v1.3 → v1.4，767 行改动）：里面有整章讲着没实现的方案（自绘骨架 / 埋点 / `AppLog` / `BackupService`）、9 个不存在的类型名、18 条动作库（实际 43）、`DongKe/Domain` 目录（实际是 `DongKeCore` framework）。

校验办法（改完文档跑一次）：把文档里所有 `` `CamelCase` `` 抓出来，对代码里 `struct|enum|class|protocol` 的名字表，差集就是可疑项。**纯人工读发现不了**。

## 完成率与剂量分账（2026-10-25）

**完成率分母锁计划组数，额外组不进分母、也不让「这一节练过没有」成立；额外组只进剂量。** 跳过一组再加两组，仍是 11/12。口径在 ADR-0006，实现只有一个出处：`SessionLedger`（按 `SetLog.origin` 分账、按逻辑键去重）。`SessionRecap` 是它的投影；**改分母先改账本，不要在视图或 `DoseReport` 里加 `filter`**。

- `SetLog.origin` 缺字段或未知值都回落 `.prescribed`；`SetLogEntity.originRaw` 可选列。`WorkoutCheckpointStore.load()` 用 `try?`，解码一抛错整条断点静默丢失——别直接 `decode(SetOrigin.self)`。
- 静态动作走保持时间轴：余力连续两次 ≤ 2 → +5 秒，上限 60 秒；到顶沉默，不转加组。余力档位对静态是 10 / 5 / 2 秒。`distanceM` 没有轴。
- 静态动作的**减量**：疼 −20% 向下取整到 5 秒（5 秒地板回落到减组），太累 −5 秒（5 秒地板沉默）；距离动作不变。
- 静态动作的**强证据**还没开：UI 不记录「多撑了几秒」，`clearedEverySet` 对静态没有可用数据，只走余力。
- 加组入口在休息页：只在该动作最后一组（或已加的额外组）之后出现，一节课最多 3 组。`WorkoutFlowModel` 保持不可变，`WorkoutSession` 另持 `script`；断点把整份 `script` 存进 `WorkoutCheckpoint.steps`，旧断点回落计划展开。完成额外组落 `origin = .extra`，跳过不落日志。
- 结束页 / 记录页 / 播报已补「额外 N 组」；播报用 `finishedWithExtras`，`extraSets == 0` 时仍走原 `.finished`。

## 环境

- **grep 会静默漏匹配**：macOS BSD grep 不支持 `\|` 交替（当字面量处理），于是 `grep -n "^## \|^### "` 返回空且不报错。用 `rg` 或 `grep -E`；看到空结果先怀疑模式，别当事实。
- 模拟器 UDID：`D16A8318-973E-45CE-936B-94F5FFE3E0EC`（iPhone 18 Pro），`content_size` 保持 `large`，不要设 AX3
- 推 origin 需代理：`git -c core.sshCommand="ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'" push origin main`

## 跑测试：必须 Python 包一层（2026-10-24）

`xcodebuild test` 跑完**不退出**，无限刷 `IDESchemeActionSDKRecord ... invalidDigitCount(94232)`（Xcode 27 解 5 位 build 号失败），测试其实几秒就跑完。

固定三步，见 `docs/HANDOFF.md` §6.25：

1. `build-for-testing`（正常退出）
2. Python `subprocess.Popen` + `wait(timeout=90)` 跑 `test-without-building`，超时 `kill()`
3. 只认日志里 `Test run with` / `✘ Test "..." failed`，**不认退出码**

⚠️ macOS 没有 GNU `timeout`，写 `timeout 200 xcodebuild` 会 `command not found`，随后 grep 空输出会被误读成「通过」。同一套写法推广到 `xcrun simctl`、`devicectl`、`swift test` 等会挂住的长命令。

## 播报：一拍一句（2026-10-25，ADR-0007）

- **一拍一句**：下一组存在时 `restFinished` 返回 nil，由 `setStart` 独唱；实测原来同 tick 连发两句 8.79 秒。
- **预算按秒**：zh-CN rate 0.5 ≈ 4.0–4.3 字/秒；组开始最短 3.8 秒，所以上限是 **≤4 秒**（20 字），硬上限 32。超预算先丢「共 N 组」。
- **端口**：`SpeechRendering`（id/priority/事件/可用性/profile），不是 `SpeechAnnouncing`（只有 `isSpeaking` 轮询）。**禁止**再用 `if isSpeaking { stop }` 当打断规则——`speak()` 返回瞬间它恒为 false，行为取决于调度时机。
- **会话**：`AudioSessionArbiter` + `AudioSessionLease` 引用计数；播报整段持有，播完 2 秒才释放（否则倒数 3/2/1 会断三次）。播报与收音都不许直接 `setActive`。
- **音色**：只传 `language: "zh-CN"` 会拿到 compact Tingting；按 `quality` 取最高档（本机有 premium「声音2」）。
- **引擎**：`matcha-icefall-zh-baker` 语料非商用、Kokoro 中文 RTF>1 且 G2P 是 eSpeak GPL——都不能闭源上架。只剩 MeloTTS（MIT / 44.1kHz / 163MB）。

### 出声权归课程，不归视图（2026-10-25，e9a9499）

- `VoiceService.voice(for: sessionId:…)` 按 sessionId 缓存；`WorkoutVoiceSession.start(atStep:)` 每实例只生效一次。**不要在 `onDisappear` 里置空会话**——fullScreenCover 转场会成对抖动，实测 onAppear 触发 3 次，每次都会重念开场。
- **第一拍是组时不念开场**：同一 tick 两句必然截断（真机只听到「开始训练，下…」）。`index > 0` 的恢复训练也不念。
- **全 App 一个渲染器**。每个协调器新建一个 `AVSpeechSynthesizer` 会各自排队，依次念完 = 听感「两个音频」。
- `AVSpeechSynthesizer.cancel` **不要用 `isSpeaking` 当开关**（`speak()` 返回瞬间恒 false）；`stopSpeaking` 无条件调用。
- `.inactive` 算前台：转场/来电横幅/控制中心都会短暂 inactive。

## 休息面板的布局约束（2026-10-25）

- **不要写死面板高度**。`RestSheetView` 用自然高度 + `Metrics` 四档间距（8/12/16/20）。改内容时高度会自己变，外层 `WorkoutView.restingInset` 靠 `onCardHeightChange` 拿到实际高度，把滚动内容上让——否则动作图会被面板从胸口切断。
- 卡片要 `.ignoresSafeArea(edges: .bottom)` + 内容让出 safeInset，不然 home indicator 那条会露灰底。
- `hasQueuedExtra` 只认「组序超出计划组数」的那一段（`WorkoutFlowModel.hasQueuedExtraSet`）。**别用「下一步还是同一动作的组」判断加组**——那是普通组间休息，会让每次休息都显示「已加一组」，而撤销会删掉正常的那一组。
- `Typography.timer` 是 rounded（不是 monospaced）：monospaced 的 0 是斜线零。
