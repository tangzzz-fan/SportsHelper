# VoiceClips

**这里放的是阶段 0 的原型音条，不进 git，也不能随包上架。**

生成：

```bash
scripts/render-voice-clips.sh          # 增量；DK_CLIP_REBUILD=1 强制重编
DK_CLIP_VOICE="婷, 增强" scripts/render-voice-clips.sh
```

- 每条一个 `WAV`（22.05kHz 单声道 16 位）+ 一个同名 `.txt` 存原文，用来判断音条是否过期。
- 文件名是 `VoiceClipBank.clipId(for:)`（FNV-1a），与运行时一致。
- 清单由 `VoiceClipBank.inventory` 决定，改语法就重跑。

## 为什么不能上架

音频是 macOS `say` 生成的，**Apple 的语音只授权个人使用**。这套音条只用来回答一个问题：**把短语拼起来，听起来像不像机器人在念单词。**

正式音条必须用许可干净的模型重渲染（CosyVoice2-0.5B，Apache-2.0），见 `.scratch/coach-voice/README.md`。

## 缺文件会怎样

`ClipSpeechRenderer` 找不到片段就整句回落系统 TTS，不会静默。所以目录为空时 App 一切正常，只是没用上音条。
