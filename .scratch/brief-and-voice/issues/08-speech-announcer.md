# 08: 播报引擎与开关

**What to build:** 真的出声，并且知道什么时候该闭嘴。

**Blocked by:** 07

**Status:** todo

- [ ] `SpeechAnnouncing` 协议 + `SystemSpeechAnnouncer`（`AVSpeechSynthesizer`，zh-CN，rate 0.5）
- [ ] `AVAudioSession` 用 `.ambient`：跟随静音键、与音乐混播、不申请后台音频；结束即释放
- [ ] VoiceOver 运行时让路（`UIAccessibility.isVoiceOverRunning` 直接不播，避免和读屏打架）
- [ ] 插话策略：新节点到来时取消未播完的旧句；来电 / Siri 中断后不补播过期内容
- [ ] App 进后台、退出训练、进总结页立即停
- [ ] 设置页开关「语音提示」默认关（`dk.voice.enabled`），AX label「语音提示，关闭 / 开启」
- [ ] 假 speaker 测试：入队 / 打断 / 停止 / 静音键不播；UI 测试开关持久化

**决策**：`.ambient` 而不是 `.playback`——默认尊重静音键，宁可少播也不在图书馆突然出声；代价是不 duck 音乐，音量大时可能听不清。

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

