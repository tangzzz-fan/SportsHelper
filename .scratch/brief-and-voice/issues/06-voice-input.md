# 06: 语音输入（Speech 转写）

**What to build:** 点按说一句，转成文字回填输入框；拒绝权限或识别不可用时退回键盘，不挡路。

**Blocked by:** 03

**Status:** todo

- [ ] `SpeechTranscribing` 协议 + `SystemSpeechTranscriber`（`SFSpeechRecognizer` zh-CN + `AVAudioEngine`）
- [ ] `VoiceInputModel` 状态机：idle → 申请权限 → 录音 → 转写 → done / failed；60 秒上限、200 字上限
- [ ] 优先 `requiresOnDeviceRecognition`；设备不支持时先提示「这一步会用 Apple 的语音服务」，同意才走在线
- [ ] 权限拒绝 / 受限 / 无识别器 / 无语音：各自文案 + 「去设置」；键盘始终可用
- [ ] Info.plist：`NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`（`project.yml` 的 `INFOPLIST_KEY_*`）
- [ ] 录音结束恢复 `AVAudioSession`，不打断正在播放的音乐
- [ ] 测试：假 transcriber 覆盖授权拒绝、部分结果、超时、空结果、超长截断；UI 测试用 `DK_VOICE_TRANSCRIPT` 注入转写
- [ ] 隐私文案：不保存音频，只留转写文本

**风险**：中文离线识别在部分机型不可用；在线识别与「数据只存本机」的承诺有张力，必须在授权前说清，而不是藏在设置里。
