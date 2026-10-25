# 离线 TTS 选型调研（2026-10-25）

> 触发：用户提到「Qwen 或火山云有自己离线的 TTS SDK」。
> 结论先说：**Qwen 没有端侧 SDK（它开源的是模型），火山有（但我们要的不是它）。**

## 0. 先把问题的形状摆正

这个项目**不需要运行时合成**。播报文案是封闭集合：`VoiceClipBank.inventory` 496 条短语（50 动作名 + 150 条要点 + 组数/次数/秒数/百分比/固定词），运行时只做「切句 → 拼接已录音频」，首音 < 20ms（`AVAudioPlayer`）。

所以真正要回答的不是「哪家 SDK 快」，而是：

> **谁能把这 496 条渲染得最好、许可最干净、成本与用户数无关？**

供给分三类，别混着比：

| 类 | 形态 | 计费口径 | 我们要不要 |
|---|---|---|---|
| A 端侧 SDK | 火山 / 阿里 / 讯飞，SDK + 离线资源包 | 按装机量或按包名，常为永久授权 | **不要**（见 §5） |
| B 云端 API | DashScope / 火山在线 / 阿里在线 / 讯飞在线 | 按字符或调用次数 | 只当对照实验 |
| C 开源自托管 | Qwen3-TTS、CosyVoice3、MeloTTS | 一次性算力 | **首选** |

## 1. Qwen：开源模型，不是 SDK

- **Qwen3-TTS**：0.6B / 1.7B 两档，12Hz tokenizer，10 种语言（含粤语/四川话等方言音色），3 秒参考音克隆，官方称流式端到端延迟 **97ms**。
- **仓库 `github.com/QwenLM/Qwen3-TTS` 的 LICENSE 已核实为 Apache-2.0**（curl 原文，非二手转述）。
- 分发形态只有四种：PyPI `qwen-tts`、**DashScope 云端 API**、vLLM-Omni 离线推理、Gradio demo。**没有 iOS / Android SDK**。
- 输出采样率：仓库页未写；第三方 Rust 运行时（candle-tts）记为 **24 kHz mono**，待官方模型卡确认。
- 权重许可：仓库代码 Apache-2.0 ≠ 权重许可，需以模型卡为准（Qwen 系列通常同为 Apache-2.0）。**本机访问 HF 被代理白名单挡住（502），这一条尚未核实**，见 §6。

**CosyVoice3**（同一团队，`github.com/QwenAudio/CosyVoice`）：
- 推荐 `Fun-CosyVoice3-0.5B-2512`，0.5B，Apache-2.0（LICENSE 已核实），Bi-Streaming 双向流式，延迟约 150ms。
- 这是当前「开源 + 许可干净 + 中文强」里最稳的一档。

## 2. 火山引擎（豆包语音）：有真端侧 SDK

- iOS SDK 为 `SpeechEngine`，支持**离线合成**：需要提前下载**离线资源包**，当前分 V2 / V4 两代，官方说明 **V2 已停止迭代，新接入用 V4**。
- **V4 模型「较大」，不能把所有音色打进一个包**：按「语种 + 音色 + 引擎类型」逐个下发（`fetchResource` → 解压到 `speechModelDir`）。
- 离线音色（V4）：灿灿 `BV700`、擎苍 `BV701`、通用女声 `BV001`、通用男声 `BV002`、开朗青年 `BV004`、温柔淑女 `BV104`、英语 Ariana `BV503`。V5 另有 `BV700_24k` 与 22 种情感（离线是否可用需确认）。
- **授权**：离线合成有两种，**按包名**（该 App 不限次）或**按装机量**（限设备数），**均需联系商务**，公开页无单价。license 文件绑定 **BundleID + 有效期**，可由服务端下发。
- 大模型 TTS 只在线，且不支持自定义音量/音高。

## 3. 阿里云（智能语音交互）：离线 SDK，永久授权

- 离线 TTS 分**标准版 / 精品版**（精品版音质更好；主频 < 1.6GHz 的设备建议标准版）。
- **商用版为永久授权，按设备数购买**，每台设备消耗一个 license；两版各有 5 个免费试用授权。
- 集成：`appkey + device_id + sdk_code` 激活，**首次激活需联网**，之后纯本地。
- 与 Qwen3-TTS **不是同一套音色与授权池**——买阿里云离线 TTS 不等于用上 Qwen 的声音。

## 4. 讯飞：唯一公开单价的

| 包 | 装机量 | 单价 | 总价 | 有效期 |
|---|---|---|---|---|
| 基础包 | 2,000 | ¥4.00/台 | ¥8,000 | 永久 |
| 中级包 | 5,000 | ¥3.50/台 | ¥17,500 | 永久 |
| 高级包 | 10,000 | ¥3.00/台 | ¥30,000 | 永久 |
| 豪华包 | 50,000 | ¥2.50/台 | ¥125,000 | 永久 |

- 发音人**另购**：普通版 2,000 元/个，高品质版 4,000 元/个（限时 2,000）。「赠送普通话男女声」。
- 试用：10 台装机量、激活后 90 天。
- iOS 9+，SDK + `AEEResource.bundle`；支持设备授权与应用授权两种。

## 5. 决策：端侧 SDK 全部不选

三条理由，任一条都足够：

1. **用不上**。文案封闭（496 条），预渲染后首音 < 20ms，比任何端侧引擎（初始化 + 首帧合成）都快。端侧 SDK 的唯一优势是「任意文本实时合成」，而我们的产品里不存在任意文本——主题名、区块名已被 ADR-0007 明令禁止进口播。
2. **成本结构反了**。端侧授权按装机量或按包名计费，用户越多越贵；而我们的成本应该固定在「渲染一次」。讯飞 5 万台要 12.5 万，这笔钱买的是一个我们用不到的能力。
3. **用途不符**。端侧 license 绑定 BundleID、按「随 App 分发」定价。拿 SDK 在构建机上批量渲染成音频再打包，属于绕开装机量计费，条款上站不住。

同理，**用云端 API 批量合成再固化成离线资源也有灰区**：大厂普遍把「离线资源」单独授权（火山按包名/装机量、阿里按设备），在线接口卖的是「每次调用」。做 A/B 试听没问题，真要作为产品音源，先让法务看一眼 ToS。

## 6. 待核实（一天内能做完）

| # | 事项 | 方法 |
|---|---|---|
| 1 | Qwen3-TTS / CosyVoice3 **权重**许可 | 在能直连 HF/ModelScope 的机器上读模型卡 `license` 字段。本机 `huggingface.co` 走代理返回 502，`127.0.0.1:7890` 也不通 |
| 2 | Qwen3-TTS 输出采样率、中文 RTF（Mac M 系列 CPU/GPU） | 本地跑 `qwen-tts`，合成现有 496 条里的 20 条取样计时 |
| 3 | 火山 V4 离线资源包体积（每个音色） | 控制台/商务；文档只说「V4 模型较大」，未给 MB |

## 7. 建议的下一步

1. **`prototype/tts-render` 分支**：用 **Qwen3-TTS-12Hz-0.6B-CustomVoice**（自带 9 个精品音色，省掉自录参考音）渲染现有 496 条，输出与 `VoiceClips/` 同结构（同 `clipId` 命名）。
2. **盲听 A/B**：同一节课、同一台 iPhone，`say` 版 vs Qwen 版 vs 系统 TTS，三个音源，只问一句「像不像一个人在说话」。
3. **门槛**（沿用 `.scratch/coach-voice/README.md`）：许可干净 / 单句时长偏差 < 15% / 总体积可控（AAC 后 < 4MB）/ 不出现句尾发飘与数字吞音。
4. 若 Qwen3-TTS 在 Mac 上 RTF > 1（纯 CPU），退 CosyVoice3 0.5B；仍不行退 MeloTTS（MIT，44.1kHz）；三者都不过，才回到「云 API 渲染 + 法务确认」。

## 8. 一句话

> 「Qwen 有离线 TTS」是对的，但那是**可自托管的开源模型**，不是 SDK；「火山有离线 TTS SDK」也是对的，但**我们不需要它**——我们需要的是构建机上的一次性渲染，而那件事用 Apache-2.0 的模型就能做，且成本与用户数无关。

## 来源

- 火山引擎 SDK 概览：<https://www.volcengine.cn/docs/6561/79827>
- 火山 iOS 接入流程（离线授权、资源包、合成场景）：<https://docs.volcengine.com/docs/6561/79837>
- 火山 模型下发接口（V4 按音色/语种下发）：<https://www.volcengine.com/docs/6561/516028>
- 火山 音色列表（含离线 V4/V5）：<https://www.volcengine.com/docs/6561/97465>
- 火山 移动端离线授权（绑定 BundleID + 有效期）：<https://docs.volcengine.com/docs/6561/1582481>
- 阿里云 离线语音合成（标准版/精品版、永久授权、5 个试用）：<https://help.aliyun.com/zh/isi/developer-reference/offline-speech-synthesis>
- 阿里云 接口说明（device_id / 首次联网激活）：<https://helpcdn.aliyun.com/document_detail/204185.html>
- 讯飞 离线语音合成价格与装机量：<https://www.xfyun.cn/service/offline_tts>
- 讯飞 离线合成服务说明（发音人 2000/4000 元）：<https://xfyun.cn/doc/tts/offline_tts/ttsoffline_description.html>
- 讯飞 AIKit 轻量版 iOS SDK：<https://xfyun.cn/doc/tts/AIkit_offline_tts/iOS-SDK(Lightweight).html>
- Qwen3-TTS 仓库（LICENSE 已核实 Apache-2.0）：<https://github.com/QwenLM/Qwen3-TTS>
- CosyVoice 仓库（LICENSE 已核实 Apache-2.0）：<https://github.com/QwenAudio/CosyVoice>
- candle-tts（Qwen3-TTS / CosyVoice3 本地推理，24kHz 记录）：<https://lib.rs/crates/tts-qwen>
