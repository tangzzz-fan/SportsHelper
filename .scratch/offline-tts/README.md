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
- 分发形态只有四种：PyPI `qwen-tts`、**DashScope 云端 API**、vLLM-Omni 离线推理、Gradio demo。**没有 iOS / Android SDK**（但已有 LiteRT / GGUF / MLX 端侧格式，见 §6c）。
- 输出采样率：**24 kHz**（`speech_tokenizer/config.json` 的 `output_sample_rate`，已核实）。
- 权重许可：**Apache-2.0，已核实**（模型卡 front-matter），见 §6.1。

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

## 6. 三条待核实的实测结果（2026-10-25）

### 6.1 权重许可：**全部 Apache-2.0，已核实**

不是看 tag，是读模型卡 front-matter 原文：

| 仓库 | 许可 | 来源 |
|---|---|---|
| `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` | apache-2.0 | README front-matter 第 2 行 |
| `Qwen/Qwen3-TTS-12Hz-0.6B-Base` | apache-2.0 | HF API tag |
| `Qwen/Qwen3-TTS-12Hz-1.7B-{Base,CustomVoice,VoiceDesign}` | apache-2.0 | HF API tag |
| `Qwen/Qwen3-TTS-Tokenizer-12Hz` | apache-2.0 | HF API tag |
| `FunAudioLLM/Fun-CosyVoice3-0.5B-2512` | apache-2.0 | HF API tag |
| PyPI `qwen-tts` 0.1.1 | Apache-2.0 | PyPI metadata |

**结论：代码与权重同许可，商用无额外条件。** 上一版担心的「代码 Apache ≠ 权重 Apache」不存在。

### 6.2 采样率 **24 kHz**，RTF **3.28**

采样率不是猜的，是 `speech_tokenizer/config.json` 原文：

```json
"input_sample_rate": 24000,
"output_sample_rate": 24000,
"decode_upsample_rate": 1920
```

这也解释了 candle-tts 记的 24 kHz 为什么对。

RTF 实测（`bench.py`，20 条真实音条，覆盖动作名/要点/数字/固定词）：

| 项 | 值 |
|---|---|
| 机器 | Apple M2（8 核）/ 16 GB / macOS 27 |
| 后端 | MPS，fp32，0.6B CustomVoice |
| 模型加载 | 7.0 s |
| RTF 均值 / 中位 / 最差 | **3.28 / 3.19 / 4.16** |
| 20 条音频总长 | 51.5 s |
| 20 条生成总耗时 | 165.4 s |

**推算全量 496 条：音频约 21 分钟，渲染约 70 分钟**（单进程，一次性构建任务）。

RTF 3.28 意味着「跑一晚」而不是「跑一分钟」，但**它不构成选型门槛**：
这是构建机上的一次性任务，不是运行时能力。之前把「RTF > 1 就退 CosyVoice3」
写进判据是错的——那条判据混淆了「离线渲染」和「实时合成」。

### 6.3 火山 V4 资源包体积：**公开渠道无数据**

翻遍 SDK 概览、模型下发接口（V4）、音色列表、移动端离线授权四份文档，
只有一句定性描述：

> V4 的模型较大，不能再将所有音色打包进同一个文件中一次性下载。

能确认的是形态变化：V2 = 多音色整包（MultipleVoice），**V4 = 单音色资源（SingleVoice）**，
按「语种 + 音色 + 引擎类型」逐个 `fetchModel` 下发。

具体 MB 数要么找商务，要么装 SDK 实测 `fetchModel` 落盘体积。**不编数字。**

## 6b. 拼接实测：音色比模型更决定成败

单条音条好听不算数——一节课听到的是「俯卧撑 / 第 2 组 / 共 3 组 / 10 次」拼起来那一句。
按 `ClipSpeechRenderer` 的 70 ms 间隔拼了四组，与现有 `say` 版对照（`concat_bench.py`）：

| 句 | say | Serena | Uncle_Fu |
|---|---|---|---|
| A 动作播报（4 段） | 3.35 s | 3.45 s（**+3%**） | 6.08 s（+82%） |
| B 开场（3 段） | 3.01 s | 3.08 s（**+2%**） | 4.58 s（+52%） |
| C 过渡（2 段） | 1.80 s | 1.66 s（**−8%**） | 2.64 s（+46%） |
| D 要点（动作名 + 长要点） | 5.91 s | 5.66 s（**−4%**） | 13.58 s（**+130%**） |

两条硬发现：

1. **必须裁首尾静音**。Qwen 每条输出固定带 **0.2 s 首 + 0.3 s 尾**静音。不裁的话
   「休息」从 0.70 s 变成 1.52 s（+117%），每段之间凭空多 0.55 s，一节 30 组的课
   会拖长近半分钟。裁掉之后 Serena 的偏差收敛到 ±8% 以内。
2. **Serena 可用，Uncle_Fu 不可用**。男声语速慢 50–130%，D 要点 13.58 s——
   播报预算（`WorkoutAnnouncement.setBudget`）是 20 字/4 秒，这条直接翻三倍。
   换男声必须先做**语速对齐**（`instruct` 指定或后处理变速），否则一节课都在等播报。

试听材料在 `.scratch/offline-tts/assets/`（已被 `.gitignore` 的 `.scratch/*/assets/` 排除）。

## 6c. 顺带发现：Qwen3-TTS 已有端侧格式

HF 上除了官方 PyPI 权重，还有：

- `litert-community/Qwen3-TTS-12Hz-0.6B-Base` —— Google **LiteRT**（原 TFLite）格式
- `Serveurperso/Qwen3-TTS-GGUF` / `cstr/qwen3-tts-0.6b-customvoice-GGUF` —— GGUF 量化版
- `mlx-community/Qwen3-TTS-12Hz-0.6B-*` —— MLX（Apple Silicon）4/5/6/8bit

这条对 §5 的决策没有影响（我们仍然不需要端侧），但它意味着：
**将来真要做「任意文本实时合成」，开源模型这条路已经通了，不必去买火山/阿里的装机量授权。**


## 6d. 怎么复现

复现材料在 `.scratch/offline-tts/tools/`（**手动跑，不进构建**）：`bench.py`（RTF）、
`compare.py`（与 say 版逐条比时长）、`concat_bench.py`（拼接整句）、`samples.tsv`（20 条取样）、
`bench-mps-Serena.csv`（原始逐条数据）。

三步：

```bash
# 1. 环境（Python 3.13 / macOS 27）
uv venv .venv && uv pip install --python .venv/bin/python qwen-tts
# 2. 权重（2.3 GB）
HF_HUB_DISABLE_XET=1 .venv/bin/python -c "from huggingface_hub import snapshot_download; \
  snapshot_download('Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice', local_dir='model')"
# 3. 跑
.venv/bin/python bench.py Serena mps      # → bench-mps-Serena.{json,csv}
.venv/bin/python compare.py               # 需先有 $TMPDIR/dk-clip-dump/inventory.tsv
.venv/bin/python concat_bench.py Serena   # → concat/*.wav
```

⚠️ **代理变量有大小写陷阱**（这里踩过一次）：会话自带 `http_proxy=http://127.0.0.1:57455`
（白名单代理，不放 huggingface.co），而 Python `requests` **优先读小写**变量。
只设 `HTTPS_PROXY` 不设 `https_proxy` 时，请求走的是 57455 → `Tunnel connection failed: 502`。
curl 相反（小写优先，但命令行 `env https_proxy=…` 会覆盖）。所以：

```bash
env -u http_proxy -u https_proxy -u ALL_PROXY HTTPS_PROXY=http://127.0.0.1:7890 … .venv/bin/python …
```

⚠️ 另两个小坑：`samples.tsv` 别带 BOM（`read_text(encoding="utf-8-sig")`）；
`mkdir(exist_ok=True)` 在本机沙箱 shim 下目录已存在仍抛 `FileExistsError`。

## 7. 建议的下一步

1. **`prototype/tts-render` 分支**：用 `Qwen3-TTS-12Hz-0.6B-CustomVoice` 的 **Serena**
   渲染现有 496 条，输出与 `VoiceClips/` 同结构（同 `clipId` 命名）。两件事必须做在渲染脚本里：
   - **裁首尾静音**（−45 dBFS 阈值，固定 0.2/0.3 s 也可直接裁）
   - **重采样 24 kHz → 22.05 kHz**（`say` 版是 22050，播放层不必改）
2. **盲听 A/B**：同一节课、同一台 iPhone，`say` 版 vs Serena 版，只问一句「像不像一个人在说话」。
3. **门槛**（已按实测修正）：
   - 许可干净 —— ✅ 已过（全部 Apache-2.0）
   - **拼接整句**时长偏差 < 15%（不是单条比单条）—— Serena 已过（≤8%）
   - 不出现句尾发飘与数字吞音 —— 只能人耳判
   - 总体积可控（AAC 后 < 4MB）
4. **不设 RTF 门槛**。实测 bf16 全量 496 条只要 **37 分钟**（RTF 2.57），构建机一次性任务，与运行时无关。
   还想更快：起 2 进程并行（16 GB 内存够，单进程约占 3 GB）。
5. **换男声必须先解决语速**。Uncle_Fu 慢 50–130%，直接替换会让每句播报超预算。
   要么 `instruct` 指定「语速稍快」，要么后处理变速（会改音色，慎用）。
6. 只有 Serena 的**音质**被人耳否决，才退 CosyVoice3 0.5B；再不行退 MeloTTS（MIT，44.1 kHz）。


## 8. 全量渲染实录（2026-10-25 实施）

496 条全部渲染完成，产物在 `.scratch/offline-tts/assets/render/`（gitignore），脚本 `tools/render_clips.py`。

| 项 | 值 |
|---|---|
| 条数 | 496 / 496 |
| 体积 | **33.2 MB**（22050 Hz PCM_16 单声道，vs say 版 41 MB） |
| 总时长 | 13.3 分钟 |
| 渲染耗时 | 37.1 分钟（476 条 bf16）+ 2 分钟（补齐/重跑） |
| RTF | **2.57**（bf16，比 fp32 的 3.28 快 22%） |
| 时长偏差 | 中位 **13.0%**、均值 19.6%、≤15% 占 55%、≤25% 占 75%（双方都裁静音后比语音段） |
| 拼接验收 | 8 句真实播报全部可切分，**0 条回落 TTS** |

### ⚠️ 最重要的一条：TTS 渲染必须做时长校验 + 重试

第一版直接渲染，496 条里 **7 条跑飞**（1.4%），最严重的是：

| 文本 | say 版 | Qwen 首次 | 倍数 |
|---|---|---|---|
| 每侧 2 次 | 1.20 s | **30.34 s** | 25× |
| 300 米 | 0.92 s | 15.55 s | 17× |
| 哑铃侧平举 | 1.41 s | 15.33 s | 11× |
| 55 秒 | — | 14.19 s | — |

这是自回归模型的**重复循环**，不是音质问题——它会把一句话念十几遍。
一条 30 秒的音条插在组间，播报会卡死半分钟，比音色难听严重得多。

**判据不能用字数估。** 第一版用 `len(text)/3 + 1.2`，结果「80 米」（4 字）的许可上限是 2.53 s，
而它跑飞到 2.41 s 刚好差一点没被抓到——正常只有 0.8 s。
改成**用 say 版同一条的语音段长度做基准**（`× 1.6 + 0.4 s`），立刻抓出 9 条。

处理策略：**每条最多尝试 4 次，取第一个在限内的；全超则取最短的并报出来。**
实测 8 条跑飞里 7 条重跑一次就正常（随机性导致），所以重试是有效解法，不需要调 temperature。

`instruct` 控语速**不可靠**：要「语速稍快一些」时「80 米」从 0.80 s 变成 0.90 s（更慢），
「用较快但清晰的语速说」时「10 次」从 0.63 s 变成 1.12 s。不采用。

### 已知偏差：短句偏慢

偏差最大的都是 4–6 字数字短语（`80 米` +261%、`9 公里` +183%、`4 个动作` +157%）。
重跑后收敛，但整体仍是「短句比 say 慢、长句比 say 快」。因为整批换音源、内部比例自洽，
拼接后的整句偏差只有 −5% / −4% / +8%（拼接会把偏差摊平）。

**这一条只能靠人耳判**：如果听完觉得「10 次」这类短语拖，再考虑对短句单独做 atempo 加速。

## 9. 一句话

> 「Qwen 有离线 TTS」是对的，但那是**可自托管的开源模型**，不是 SDK；「火山有离线 TTS SDK」也是对的，但**我们不需要它**——我们需要的是构建机上的一次性渲染，而那件事用 Apache-2.0 的模型就能做，且成本与用户数无关。

实测之后补两句：
> 模型能跑（RTF 2.57，40 分钟出全量），许可干净（Apache-2.0），**真正的选择题是音色**——
> Serena 拼接后与现有节奏差 ±8%，Uncle_Fu 慢到 +130%。换音色不是换个名字，是重做语速对齐。

> 还有一条比音色更硬：**每条音条渲染完必须校验时长并重试**。
> 自回归 TTS 有 1.4% 的概率把「每侧 2 次」念成 30 秒，插在组间就是播报卡死半分钟。
> 判据不能用字数估，要用现有音条的实际长度做基准。


## 来源

- 火山引擎 SDK 概览：<https://www.volcengine.cn/docs/6561/79827>
- 火山 iOS 接入流程（离线授权、资源包、合成场景）：<https://docs.volcengine.com/docs/6561/79837>
- 火山 模型下发接口（V4 按音色/语种下发，单音色资源）：<https://www.volcengine.com/docs/6561/516028>
- 火山 模型下发接口（V4，iOS/OC 版）：<https://www.volcengine.com/docs/6561/516112>
- 火山 环境依赖（V2/V4 资源包、`OFFLINE_RESOURCE_PATH`）：<https://www.volcengine.com/docs/6561/79834>
- 火山 音色列表（含离线 V4/V5）：<https://www.volcengine.com/docs/6561/97465>
- 火山 移动端离线授权（绑定 BundleID + 有效期）：<https://docs.volcengine.com/docs/6561/1582481>
- 阿里云 离线语音合成（标准版/精品版、永久授权、5 个试用）：<https://help.aliyun.com/zh/isi/developer-reference/offline-speech-synthesis>
- 阿里云 接口说明（device_id / 首次联网激活）：<https://helpcdn.aliyun.com/document_detail/204185.html>
- 讯飞 离线语音合成价格与装机量：<https://www.xfyun.cn/service/offline_tts>
- 讯飞 离线合成服务说明（发音人 2000/4000 元）：<https://xfyun.cn/doc/tts/offline_tts/ttsoffline_description.html>
- 讯飞 AIKit 轻量版 iOS SDK：<https://xfyun.cn/doc/tts/AIkit_offline_tts/iOS-SDK(Lightweight).html>
- Qwen3-TTS 仓库（LICENSE 已核实 Apache-2.0）：<https://github.com/QwenLM/Qwen3-TTS>
- Qwen3-TTS 0.6B CustomVoice 模型卡（`license: apache-2.0`、9 音色表）：<https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice>
- Qwen3-TTS 0.6B `speech_tokenizer/config.json`（24 kHz 出处）：<https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice/blob/main/speech_tokenizer/config.json>
- CosyVoice 仓库（LICENSE 已核实 Apache-2.0）：<https://github.com/QwenAudio/CosyVoice>
- Fun-CosyVoice3-0.5B-2512（apache-2.0）：<https://huggingface.co/FunAudioLLM/Fun-CosyVoice3-0.5B-2512>
- PyPI `qwen-tts`（Apache-2.0，依赖 torch/transformers 锁定版本）：<https://pypi.org/project/qwen-tts/>
- LiteRT 版 Qwen3-TTS：<https://huggingface.co/litert-community/Qwen3-TTS-12Hz-0.6B-Base>
- candle-tts（Qwen3-TTS / CosyVoice3 本地推理，24kHz 记录）：<https://lib.rs/crates/tts-qwen>

