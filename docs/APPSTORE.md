# App Store 提审材料

> 这一页是 App Store Connect 各字段的**唯一填写来源**，逐项复制即可。
> 隐私政策与支持页的正文在 `docs/appstore/`，托管方式见该目录 README。
> 素材（截图）的维护点在 `docs/RELEASE.md` §2.1，这里不重复。

**当前版本**：1.0.0 (build 1) ｜ **Bundle ID**：`app.dongke.ios` ｜ **语言**：简体中文（仅此一种）

## 0. 字段总览

| ASC 字段 | 值 | 长度 | 状态 |
|---|---|---|---|
| App 名称 | 动刻 | 2 / 30 | ⚠️ 需在 ASC 查是否被占 |
| 副标题 | 把 AI 计划变成今天的训练 | 14 / 30 | ✅ |
| 促销文本 | 见 §2.2 | 68 / 170 | ✅ 可随时改，不用重新提审 |
| 描述 | 见 §2.3 | 854 / 4000 | ✅ |
| 关键词 | 见 §2.4 | 71 / 100 | ✅ |
| 支持 URL | 见 §2.5 | — | ❌ 未托管 |
| 隐私政策 URL | 见 §2.5 | — | ❌ 未托管 |
| 营销 URL | 可留空 | — | 选填 |
| 类别 | 健康健美（Health & Fitness） | — | ✅ 次要类别留空 |
| 版权 | 2026 〔主体名称〕 | — | ❌ 待填真实主体 |
| SKU | `DONGKE-IOS-001` | — | ✅ 只用于报表，可自定 |
| 定价 | 免费，无内购 | — | ⚠️ 见 §7.3 |
| 年龄分级 | 4+ | — | ✅ 问卷答案见 §3 |
| 审核备注 | 见 §5 | — | ✅ 需替换联系邮箱 |

## 1. 名称与备选

主选 **动刻**（与 `CFBundleDisplayName` 一致，改了要同步 `project.yml` 第 62 行）。

ASC 的名称在**同一店面内唯一**，先建 app 记录时就能看出是否被占。被占时按顺序换：

1. 动刻训练
2. 动刻 · 把计划做完
3. 刻练

不要选「动刻健身」——健身类目里带「健身」二字的重名率最高。

## 2. 商店文本

### 2.1 副标题

```
把 AI 计划变成今天的训练
```

### 2.2 促销文本（170 字，可随时改）

```
三种入口都能把 AI 写的计划变成今天的日程：粘贴、直连 AI、或者用本地规则直接排一周。练的时候逐组播报，做不动只降这一组，不判失败。
```

### 2.3 描述（4000 字，已按 854 字定稿）

```
动刻不写计划，它负责把计划做完。

你用 ChatGPT、Claude 或别的模型写过训练计划——粘进动刻，它变成「今天几点、做哪个动作、几组几次、休息多久」的日程。到点提醒，跟着做，一组一组打勾。

【三种入口，总有一条能进】
· 粘贴：一段文字或 JSON 都行，自动拆成动作、组数、次数与休息；识别完先在校对页逐条改，再保存
· 直连 AI 生成：已内置 DeepSeek，点一下就能排；也可以换成自己的 OpenAI 兼容接口
· 不想写也行：按目标、器械、每周天数、单次时长，用本地规则排一周，不联网也能用

【练的时候不用记】
· 逐组引导：当前动作、第几组、共几组、做几次，一屏只看一件事
· 组间休息自动计时，结束前 3 秒倒数；可以加 30 秒，也可以直接跳下一组
· 语音播报：整节课逐组念出来，手机放口袋也能跟
· 做不动有出口：「这组做不动」只降这一组，不算失败；也可以降阶成更轻的同类动作，或跳过并记下原因
· 想加一组就加：加的那组不进完成率分母，完成率只算计划内的
· 中途退出不丢：回来从断点继续，不从头再来

【练完看得见】
· 完成率、降阶率、跳过率三个数并列——100% 不会掩盖「每组都减半」
· 剂量报告：总组数、总次数、总时长、总距离
· 记录页有「这周练到哪儿」、四周有效组走势、跳过原因分布，以及最近几次训练
· 训练日提醒按计划自动排，最多 7 条，不轰炸

【50 个动作，每个都有要点和更轻的替代】
35 个常用动作配了起始、过程、结束三帧线条图示，另附常见错误。

【数据只在这台手机上】
没有账号，不用登录。档案、计划和打卡记录都存在本机，卸载即清空。除了你主动点「AI 生成」与语音输入，它不联网——录音优先在本机识别。

【先把话说清楚】
本应用提供通用训练安排和动作提示，不提供医疗建议，不能替代医生或康复师。有伤病史、慢性病或处于孕期，请先咨询专业人士。训练中出现关节刺痛、麻木、头晕、胸闷，请立即停止。

计划是你选的。动刻只负责让它发生。
```

### 2.4 关键词（100 字，逗号分隔，不写空格）

```
健身,力量训练,居家,自重,哑铃,无器械,减脂,增肌,组数,计时,打卡,动作库,运动记录,私教,跟练,断点续练,健身计划,家庭健身,核心,热身
```

不重复副标题里已有的「训练计划」「AI」——名称与副标题本身已进索引，关键词位置留给同义词。

### 2.5 URL

| 字段 | 值 |
|---|---|
| 支持 URL | `https://<域名>/support.html` |
| 隐私政策 URL | `https://<域名>/privacy.html` |
| 营销 URL | 留空 |

页面已写好：`docs/appstore/privacy.html`、`docs/appstore/support.html`。两者都不引用外部资源（无 CDN、无字体、无统计），可以直接丢到任意静态托管。

## 3. 年龄分级问卷

结果应为 **4+**。逐项（选项名以 ASC 实际界面为准，2025 年后是 4+/9+/13+/16+/18+ 五档）：

| 问卷项 | 答案 | 理由 |
|---|---|---|
| 卡通或幻想暴力 | 无 | — |
| 写实暴力 | 无 | — |
| 长时间的血腥暴力 | 无 | — |
| 脏话或粗俗幽默 | 无 | — |
| 成熟或暗示性主题 | 无 | — |
| 恐怖或惊悚主题 | 无 | — |
| 医疗或治疗信息 | **无** | 只有通用训练动作与日程，不做诊断、不给用药建议，页内有免责声明 |
| 烟酒毒 | 无 | — |
| 赌博（含模拟） | 无 | — |
| 色情或裸露 | 无 | — |
| 无限制网页访问 | **否** | 只有 AI 接口的 HTTPS 请求，没有内嵌浏览器 |
| 用户生成内容 | **否** | 用户输入只用于生成自己的计划，不公开、不分享给他人 |
| 消息与聊天 | 否 | — |
| 广告 | 否 | 无广告 SDK |
| App 内购买 | 否 | 无 StoreKit |
| 家长控制 / 年龄保证 | 不适用 | 不做家长控制功能 |

## 4. App 隐私问卷

必须与 `DongKe/PrivacyInfo.xcprivacy` 一致。仓库里那份写的是：`NSPrivacyTracking = false`，采集 `UserContent` / 非关联 / 非追踪 / 用途 App 功能，访问 API 只有 UserDefaults `CA92.1`。

**是否收集数据：是**（只有一类）

| ASC 里的项 | 答案 |
|---|---|
| 数据类型 | 用户内容 → **其他用户内容**（用户写的训练需求、粘进来的计划文本） |
| 用途 | App 功能 |
| 是否与用户身份关联 | **否**（没有账号、没有设备标识） |
| 是否用于追踪 | **否** |
| 健康与健身 | **不勾**——训练记录只在设备本地，从不上传 |
| 标识符 / 使用数据 / 诊断 | 不勾 |
| 位置 / 联系人 / 照片 / 音频 | 不勾（录音不上传，也不存盘） |

一句话依据：Apple 的定义是「数据离开设备才算收集」。本 app 只有一处出网——用户点「AI 生成」时把需求文本发给模型服务商，所以只勾这一项。

## 5. 审核备注（英文，粘进 App Review Information → Notes）

```
Thank you for reviewing DongKe (动刻).

WHAT IT IS
DongKe turns a training plan into an executable schedule: which exercise today,
how many sets and reps, how long to rest. It is a scheduling and execution tool,
not a medical or coaching service.

NO ACCOUNT
There is no sign-up, login, or user account, so no demo credentials are needed.
A fresh install opens a 5-step questionnaire (basics, goal, level, availability,
health & reminder), then generates a weekly plan on device.

HOW TO REACH EVERY FEATURE (about 2 minutes)
1. Launch, complete the 5 steps. A weekly plan is generated locally, no network.
2. Tab 今日, tap 开始训练. The workout runs set by set with spoken cues and a
   rest timer. Tap 完成本组 to advance; the rest screen offers +30s and skip.
3. Finish the session to see the summary (completion / deload / skip rate and a
   dose report). Tab 记录 shows weekly distribution and a 4-week trend.
4. Tab 计划, use 生成 or 导入 to create another plan. 动作库 lists 50 exercises
   with cues, common mistakes and regression options.

AI FEATURE AND NETWORK USE
The app ships with a built-in DeepSeek key so the AI option works out of the box.
Users may also enter their own OpenAI-compatible endpoint and key in 设置, AI 直连.
Network is used only when the user taps 用 AI 生成. On failure the app shows the
error, and if the key is rejected it offers a shortcut to that settings card. AI is
one of three ways to create a plan: the on-device generator (used during onboarding
and in 计划, 调整) needs no network at all, so the app stays fully usable offline.
No training records are transmitted; only the text the user typed and the profile
answers required to build the plan.

MICROPHONE AND SPEECH RECOGNITION
Voice input on the plan screen is optional. Recognition runs on device when the
device supports it (requiresOnDeviceRecognition = true). If not supported, the
app asks for explicit consent before using Apple's online recognition. Audio is
never stored or sent to our servers.

NOTIFICATIONS
Local notifications only: up to 7 weekly repeating triggers per plan, one per
training day. Permission is requested during onboarding; declining leaves the
app fully usable.

HEALTH
The app provides general exercise scheduling. It does not diagnose, treat or
rehabilitate. A disclaimer is shown in 设置, 健康提示与免责, and is repeated in the
App Store description.

OTHER
No in-app purchases, no advertising, no third-party SDKs, no analytics, no
tracking. Data is stored locally with SwiftData; 设置, 清空全部数据 removes all
of it.

Contact: <联系邮箱>
```

## 6. 出口合规

`ITSAppUsesNonExemptEncryption = NO` 已在 `project.yml` 配好（第 63 行），ASC 里选「App 不使用加密，或仅使用豁免的加密」即可——只有 HTTPS 标准加密。

## 7. 提交前的卡点

### 7.1 必做，不做提交不了

| # | 事项 | 归属 |
|---|---|---|
| 1 | 两页网页托管，拿到真实 URL | 见 `docs/appstore/README.md` |
| 2 | 建 ASC app 记录（`app.dongke.ios`），确认「动刻」可否用 | 账号持有人 |
| 3 | 隐私政策与支持页里的联系邮箱、运营主体换成真的 | 账号持有人 |
| 4 | DeepSeek 换新 Key + 设消费上限（`docs/RELEASE.md` §1.1） | 账号持有人 |

### 7.2 应该做，影响观感或审核

| # | 事项 | 说明 |
|---|---|---|
| 5 | `05-记录.png` 重拍 | 图上「本周有效组 0」与五条 100% 记录并列，是演示数据缺 SetLog，不是产品缺陷；补日志重拍即可 |
| 6 | 计划页底部标签栏遮挡 | `3-计划.png` 因此没进商品图；提交前修或者继续不放进截图 |
| 7 | 真机听感复核 | 496 条音条已装 iPhone 16 Pro，音色一致性、音量、停顿还没回 |
| 8 | 上线前跑一遍引导 | Release 包不 seed 演示数据（`#if DEBUG` 包着），首次启动是干净问卷 |
| 9 | App 预览视频 | 选填。要传就 15–30 秒、H.264、886×1920（6.9"）或 1206×2622 档，不能含设备外框 |

### 7.3 需要拍板

- **定价**：当前代码里没有 StoreKit，只能免费。要收费就得先接内购、再走一遍审核
- **中国区**：需要 ICP 备案号。没有就只能先上其他区（`docs/RELEASE.md` §4）
- **App 内文案与内置 Key 不一致**：`HealthNoticeView.swift` 第 39 行写「走你自己填的接口」，
  但 `ai-defaults.json` 已内置 Key，设置页也写「已内置 DeepSeek」。审核会对照商店文案与
  app 内说法，建议改成「只有你点『AI 生成』时才会联网」。这句在隐私政策里已按内置 Key 写

## 8. 提交时序

1. 托管两页网页 → 填 URL
2. ASC 建 app 记录 → 填 §1–§6
3. 上传构建（Xcode Organizer，见 `docs/RELEASE.md` §5）
4. TestFlight 内测一轮：安装包、音条、通知、断点续练
5. 选构建 → 提交审核 → 附 §5 备注
