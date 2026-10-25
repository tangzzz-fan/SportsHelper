# 音频审计 · audio-audit（2026-10-25）

范围：**训练播报（TTS）**、**语音输入（STT）**、以及提示音 / 通知声两类短音。
依据：SPEC F12 + AC-24、`docs/decisions/OPEN-DECISIONS.md` 2026-10-24 两条、`docs/adr/0001`（不用 AI 也要能开始）。
PRD 只有存档效力且 **F12 指「动作替换推荐」，从未收录语音播报**——音频没有产品层验收，只有 SPEC 一行。

## 1. 现状：四条出声、两条链路、一个共享单例

| 链路 | 入口 | Core（可测） | App（AVFoundation） | 音频会话 | 规格 |
|---|---|---|---|---|---|
| 播报 TTS | `WorkoutSession` 4 个方法 | `WorkoutVoiceSession` → `WorkoutAnnouncementBuilder` → `WorkoutAnnouncement.text` → `SpeechCueCoordinator`（三布尔闸门） | `SystemSpeechAnnouncer`（AVSpeechSynthesizer, zh-CN, rate 0.5） | `.ambient` + `.mixWithOthers` | SPEC F12 / AC-24 |
| 语音输入 STT | `VoiceInputBar`（只挂在 `AIGenerateCard`） | `VoiceInputMachine`（6 态、60s / 200 字） | `SystemSpeechTranscriber`（SFSpeechRecognizer + AVAudioEngine） | `.record` + `.measurement` + `.mixWithOthers` | **SPEC 无此功能**，只有 OPEN-DECISIONS 一句「文字 + 语音输入」 |
| 提示音 | `WorkoutView` 两个 token | 无 | `Haptics` → `AudioServicesPlaySystemSound(1057)` | 系统短音，不占会话 | AC-12（休息归零） |
| 通知声 | `NotificationService` | 无 | `UNNotificationSound.default` | 系统 | AC-08 |

闸门只有一个：`SpeechCuePolicy.allowsSpeech = isEnabled && isForeground && !isVoiceOverRunning`。
两个 App 侧服务**各自** `setActive(true/false)` 同一个 `AVAudioSession.sharedInstance()`，没有仲裁者；今天不出错是因为播报与收音不在同一屏。

## 2. 实测（macOS Tingting / rate 0.5；iOS 同一 voice、同一默认速率）

| 文案 | 字数 | 实测 |
|---|---|---|
| 开始训练，上肢与核心，3 个动作，共 9 组 | 22 | **5.91s** |
| 俯卧撑，第 1 组，共 3 组，10 次 | 20 | **3.75s** |
| 俯卧撑，第 3 组，共 3 组，10 次，下一个：哑铃划船 | 29 | **6.16s** |
| 休息，1 分 30 秒，接下来：平板支撑，40 秒 | 25 | **5.60s** |
| 休息结束，下一个：俯卧撑，12 次 | 17 | **4.23s** |
| 完成 12 组，完成率 100%，另有 3 组加练 | 25 | **5.21s** |
| 3 / 时间到 / 加油，最后 5 秒 | 1 / 3 / 9 | 0.60 / 0.98 / 2.13s |

**速率 ≈ 4.0–4.3 字/秒**。`WorkoutAnnouncement.textLimit = 40` 字 ≈ **10 秒**，比任何真实文案都长，等于没有上限。

## 3. 最硬的一处：休息归零同 tick 发两句

`WorkoutSession.refresh()` 在同一轮里先 `voice.restFinished(...)`（4.23s）再 `advance()` → `voice.stepChanged(...)`（3.75–4.80s）。
实测（gap = 0）：**两句都完整播出，合计 8.79s**；第二句说完时用户已在做第 1 组 8.8 秒。
实测（gap = 60ms）：第一句在 **0.11s** 被 `stopSpeaking(.immediate)` 切断，用户只听到「休息结束」。

同一份代码，两条不同体验，取决于主线程调度。原因：`SystemSpeechAnnouncer.speak` 用 `if synthesizer.isSpeaking { stop }` 当打断规则，而 `speak()` 返回时 `isSpeaking` 仍是 `false`（实测），所以同 tick 一律走**排队**，晚 60ms 才走**打断**。

配套三处同源问题：

- `SpeechCueCoordinatorTests` 有一条叫「后一句由引擎打断前一句」——**名字与真实行为相反**，`FakeAnnouncer` 只 append，测不到。
- 组计时到点：`Haptics.setTimeUp()` 的系统音 1057 与播报「时间到」在同一个 tick 触发，两个声源叠加。
- 每句 `didFinish` 都 `setActive(false)`，而队列里可能还有下一句（倒数 3/2/1 各是一句）。真机待验。

## 4. SPEC 与代码的偏差

| 项 | SPEC | 代码 | 判定 |
|---|---|---|---|
| 触发点 | F12：开始 / 每组 / 休息归零 / 换动作 / 完成；AC-24 只写「进入新的一组」与「休息归零」 | 9 类：含**休息开始**、**跨区块休息**、**动作中提示（要点 / 剩余 3 秒 / 时间到 / 加油）** | 多做；动作中提示无 spec 出处 |
| 休息归零 | AC-24「必须朗读对应文案」 | 朗读两句，重复同一信息 | 字面满足，体验不成立 |
| 语音输入 | 无 | 60s / 200 字 / 五态授权 / 在线同意 | 隐性约束，无验收 |
| 静音键 | AC-24「不得发声」 | `.ambient` 满足 | 达成，但界面**无任何反馈**（用户会以为功能坏了） |
| VoiceOver 让路 | 无 | 有闸门 | 只在 `scenePhase` / 开关变化时刷新，**中途打开 VoiceOver 不生效** |
| 中断 / 拔耳机 | 无 | 无 `interruptionNotification` / `routeChangeNotification` | 来电报错保持 `.listening`；拔耳机继续外放 |
| 测试 | 单测全绿 | 文案 29 + 闸门 11 + 流程 21 + 语音输入 42 | 决策层有覆盖，**出声层零覆盖**（App target 无测试） |

## 5. 已定（2026-10-25，ADR-0007）

| 问题 | 结论 |
|---|---|
| 休息归零说几句 | **一句**。合并成「俯卧撑，第 3 组，共 3 组，12 次」；只有没有下一组时才念「休息结束」 |
| 动作中提示 | 只留**中段一句要点**与**最后 3 秒倒数**；删「时间到」（系统音已表达）、删「加油」（死代码） |
| 预算 | **按秒**：单句 ≤4 秒（组开始实测下限 3.8 秒，3 秒做不到）。删 40 字上限 |
| 打断语义 | 两级：`instruction` 后到者赢、`aside` 丢弃。**删掉 `.countdown`**——它会让倒数「1」把下一组那一拍整句挤掉。**不做 deadline**（不排队） |
| 音色 vs 引擎 | **先换音色**：代码只传 `language:`，实测取到 compact Tingting，而机器上装着 premium「声音2」。换引擎要过三条门槛（许可 / RTF / 体积） |

## 5.1 引擎选型（2026-10-25 核查）

| 模型 | 许可 | 体积 | 实时性 | 判定 |
|---|---|---|---|---|
| matcha-icefall-zh-baker | **非商用**（DataBaker） | 165MB | 快 | 排除 |
| vits-icefall-zh-aishell3 | Apache-2.0 | 29MB / 8kHz | 快 | 音质不赚 |
| vits-melo-tts-zh_en | MIT | 163MB / 44.1k | RPi4 RTF 2.5 | 唯一值得实测 |
| Kokoro multi-lang | 权重 Apache，中文 G2P 为 eSpeak **GPL-3.0** | 88–310MB | iPad RTF 1.5–1.8 | 排除 |
| Piper zh_CN-huayan | 未声明 / 非商用音色 | 63MB | RTF<1 | 排除 |

运行时：**sherpa-onnx**（Apache-2.0，官方 Swift API + iOS 示例）。

## 6. 端口形状（已进 ADR-0007）

- `SpeechRequest { id, text, priority, expiresAt }` + `SpeechOutputEvent`，替掉 `isSpeaking` 轮询。
- 合并发生在 `WorkoutVoiceSession`（Core，可测），不在 App。
- 会话归 `AudioSessionArbiter`（引用计数），播报与收音不再各调 `setActive`。
- 出声层可观测：真机日志记 `text / 计划时长 / 实际时长 / 是否被打断`。

## 7. 票

| # | ticket | blocked by |
|---|---|---|
| 01 | 一拍一句 | done |
| 02 | 端口重画 | done |
| 03 | 会话仲裁 | done |
| 04 | 音色与试听 | done |
| 05 | 中断、路由与 VoiceOver | done（含倒数优先级与整段持有会话） |
| 06 | 神经引擎试点（有门槛） | todo（要下 163MB 模型 + 真机） |
| 07 | 真机验收（并入 brief-and-voice 10） | todo（需真机） |


## 8. 首测第二轮：两个音频（2026-10-25）

反馈「点提前练一次出现两个音频」。日志同一句开场被送进渲染器三次。四个原因叠在一起：

| # | 原因 | 证据 |
|---|---|---|
| 1 | 播报会话归视图持有，`onAppear`/`onDisappear` 成对抖动 | 同一节课 `policy` 出现 3 次，其间 `deactivate → activate` 一轮 |
| 2 | 开场与第一组同 tick 并列，后到者把开场截断 | `speak 开始训练，下肢力量` → `cancel` → `clip play 开合跳…` |
| 3 | 每个协调器新建一个 `AVSpeechSynthesizer` | 多个 `activate playback` + 多次 `speak` 同文本 |
| 4 | `cancel()` 用 `isSpeaking` 挡停 | 该值为 false 时跳过 `stopSpeaking`，上一句仍在念 |

修法与判据见 ADR-0007「一课一嘴」。回归靠三条单测：开场只念一次、第一拍是组时让位、恢复训练不念开场。
