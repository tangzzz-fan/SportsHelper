# 08: 播报引擎与开关

**What to build:** 真的出声，并且知道什么时候该闭嘴。

**Blocked by:** 07

**Status:** done（2026-10-24；「退出训练 / 进总结页立即停」的挂载点归 09）

- [x] `SpeechAnnouncing`（Core 协议）+ `SystemSpeechAnnouncer`（App，`AVSpeechSynthesizer`，zh-CN，rate 0.5）
- [x] `AVAudioSession` 用 `.ambient` + `.mixWithOthers`：跟随静音键、与音乐混播、不申请后台音频；念完 / 取消时释放会话
- [x] VoiceOver 让路：`SpeechCuePolicy.isVoiceOverRunning` 为真时一句都不念
- [x] 插话策略：新节点到来直接 `stopSpeaking(.immediate)` 再念；关开关 / 进后台立刻掐断当前句
- [ ] App 进后台、退出训练、进总结页立即停 —— **policy 由训练页驱动，随 09 接**
- [x] 设置页「语音提示」开关，默认关（`dk.voice.enabled`），带 `accessibilityLabel`
- [x] 测试：假 speaker 11 条（闸门 / 让路 / 打断 / 恢复）+ UI 开关持久化 1 条

**关键改动：闸门不在 App 里**。`SpeechCuePolicy`（开关 / 前台 / VoiceOver）+ `SpeechCueCoordinator` 都放在 `DongKeCore`，依赖一个 `SpeechAnnouncing` 协议，所以「什么时候不该说话」全部能在单测里跑；App 里的 `SystemSpeechAnnouncer` 只剩 AVFoundation 粘合（约 60 行），不承载判断。

**决策**：`.ambient` 而不是 `.playback`——默认尊重静音键，宁可少播也不在图书馆突然出声；代价是不 duck 音乐，音量大时可能听不清。

**没做**：中断（来电 / Siri）后不补播——`.ambient` 下系统会自行混音，`stopSpeaking` 已覆盖主动打断；等真机上真遇到来电再补 delegate 分支，不凭空写。

## 选型（2026-10-24）

结论：**MVP 用系统 `AVSpeechSynthesizer`**，不引第三方。

| 方案 | 许可 | 体积 | 中文 | iOS 接入 | 结论 |
|---|---|---|---|---|---|
| AVSpeechSynthesizer | 系统 | 0 | 系统音色，短句够用 | 低 | **采用** |
| sherpa-onnx + 中文 VITS | Apache-2.0 运行时，模型逐个确认 | 运行时 + 60–120MB 模型 | 好 | 中高（xcframework + ONNX） | 需要品牌音色时再评估 |
| Piper `zh_CN-huayan` | 代码 MIT，但依赖 eSpeak-ng GPL-3.0 做音素化 | ~63MB | 中等 | 中 | 不采用，许可污染 |
| Kokoro-82M | 权重 Apache-2.0，G2P 同样依赖 eSpeak-ng | ~86MB | 好 | 高 | 不采用，许可 + 接入成本 |
| MeloTTS / CosyVoice | MIT / Apache-2.0 | 200MB+ | 好 | 很高（PyTorch 系） | 本期不碰 |
| Edge TTS | 非开源，需联网 | 0 | 好 | 低 | 不采用，违背离线承诺 |

重新评估的触发条件：需要统一品牌音色、或要把语音输入也换成离线引擎（sherpa-onnx 可同时做 ASR + TTS）。届时先做一周 spike，量首字延迟、安装包增量、中文多音字准确率，再决定是否改 FROZEN 的「零第三方依赖」。
