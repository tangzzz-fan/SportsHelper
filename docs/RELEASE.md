# 上架清单

> 状态：启动屏已完成，其余按顺序推进。**先看 §1 的两条阻断项**——不解决就提交不了，
> 或者提交了会被拒/被薅。

## 0. 已经做完的（本轮）

| 项 | 结果 |
|---|---|
| Info.plist | 全部交给 `GENERATE_INFOPLIST_FILE` + `INFOPLIST_KEY_*`，仓库里**不维护自己的 plist**（与 `Fluent work/fluentwork-ios` 同一做法） |
| 启动屏 | **品牌绿**。`UILaunchScreen` 是嵌套字典，而 Xcode 只有两个启动屏设置（`UILaunchScreen_Generation` 只会塞空字典、`UILaunchStoryboardName` 传文件名），**没有设颜色的入口**，所以配了 12 行的 `DongKe/Resources/LaunchScreen.storyboard` + `LaunchBackground` 颜色集。Info.plist 仍是 `GENERATE_INFOPLIST_FILE` 生成，没有自定义 plist |
| 版本号 | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 提到顶层。**embed 的 framework 缺 `CFBundleShortVersionString` 会被 App Store 直接拒**：`The bundle 'Payload/DongKe.app/Frameworks/DongKeCore.framework' is missing plist key` |
| 签名 | 自动签名下**不要**写 `CODE_SIGN_IDENTITY`。Xcode 按用途自己挑（debug → Apple Development，Archive → Apple Distribution）。手动指定会报 `conflicting provisioning settings` |
| 真机 / 归档 | 真机 build、模拟器 build、`ARCHIVE SUCCEEDED` 均通过；archive 内 `DongKeCore.framework` 版本号已是 `1.0.0 / 1` |

## 1. 阻断项

### 1.1 内置 API Key 是明文，且在包里

`DongKe/Resources/ai-defaults.json` 里有：

```json
{ "baseURL": "https://api.deepseek.com/v1", "apiKey": "sk-ec91…3428" }
```

这个文件会被打进 `.app`，**任何人下载 ipa 解压就能拿到 Key**，直接刷你的 DeepSeek 账户。
它也已经进了 git 历史，删文件不等于泄露解除。

**决策（2026-10-25）：保留内置 Key，由服务商侧配额兜底。** 提交前必须做完这四步：

1. **去 DeepSeek 控制台给这个 Key 设消费上限**，额度按「够审核与早期用户用」定。这是唯一真正的护栏——
   客户端限流没有意义，Key 一旦被提取就在你控制之外
2. **确认这家 Key 所在账户不绑其他服务**，避免配额被刷穿时牵连别的业务
3. **换掉现在这把**（`sk-ec91…3428` 已在 git 历史里，视为已泄露）。新 Key 只写进
   `ai-defaults.json`，不要再粘到聊天、日志、截图里
4. **把这一条写进隐私政策**：说明了「app 内置 Key，只有你点『用 AI 生成』时才把档案发给服务商」。
   `AISettingsCard` 里已有同义文案，商店隐私政策要再写一次

残留风险（知情后接受）：有人解包把 Key 拿去做别的事、额度被刷光导致正常用户用不了 AI。
App 隐私问卷要如实填「收集 → 用户内容 → App 功能」，因为数据确实会发到 DeepSeek。

备选路线（若日后想收回这条风险）：删空 `apiKey` 字段，`AISettingsCard` 已支持用户自填并存钥匙串，
代码不用改；本地规则生成器 `PlanGenerator` 不受影响。

### 1.2 iPad 支持 —— 已解决

原状态：`TARGETED_DEVICE_FAMILY = "1,2"`，但没有 iPad 布局分支，
`UISupportedInterfaceOrientations` 也只有 iPhone 那份。这样提交，审核会在 iPad 上跑，按 2.1 / 4.2 拒。

**决策（2026-10-25）：改成 iPhone only**，`project.yml` 里 `TARGETED_DEVICE_FAMILY: "1"`。
iPad 上仍能以兼容模式安装，只是不做原生适配。截图只需 iPhone 一套。

## 2. 提交前要准备的素材

| 项 | 要求 | 现状 |
|---|---|---|
| App 名称 | 30 字以内，不能与已有 app 重名 | 「动刻」待确认是否被占 |
| 副标题 | 30 字以内 | 待写 |
| 描述 | 突出「本地生成计划 + 语音带练 + 不用登录」 | 待写 |
| 关键词 | 100 字以内，逗号分隔 | 待写 |
| 截图 | **6.9" 必备**：1320×2868，RGB 无 alpha，单张 ≤ 8 MB，3–10 张 | **已出 5 张**，见 §2.1 |
| 隐私政策 URL | **必填**，可公开访问 | **没有**，见 §3 |
| 支持 URL | 必填 | 没有 |
| 年龄分级 | 健身教学，无成人/暴力内容 → 4+ | 待填问卷 |
| App 隐私问卷 | 与 `PrivacyInfo.xcprivacy` 一致 | 取决于 §1.1 选哪条 |
| 出口合规 | `ITSAppUsesNonExemptEncryption = false`（只用 HTTPS 标准加密） | 已配 |
| 审核备注 | 说明 AI 生成需要 Key（若走方案 A），附一台不用登录的说明 | 待写 |

## 2.1 商品图（已生成）

成品在 `.scratch/appstore/assets/marketing/`，按**设备档位**分目录（已被 gitignore，脚本在 `tools/`）：

```
1206x2622/           iPhone（必需档）+ 5 张
1320x2868/           iPhone（可选大屏档）+ 5 张，同一份设计
2007x2853-duo-inner/ iPhone Duo 内屏 + 2 张（两屏并排）
1398x2034-duo-outer/ iPhone Duo 外屏 + 2 张
```

**尺寸这张表比任何教程都准**（2026 年 Apple 按「有没有灵动岛 + 屏幕大小」分档，
不再是「6.9 英寸」）：

| 档位 | 机型 | 接受尺寸 | 是否必需 |
|---|---|---|---|
| Dynamic Island (**medium**) | iPhone 18 Pro / 17 Pro / 16 Pro / 15 Pro | 1179×2556 · **1206×2622** | **必需** |
| Dynamic Island (large) | iPhone Air / 18 Pro Max / 17 Pro Max / 16 Pro Max | 1260×2736 · 1290×2796 · 1320×2868 | 可选 |
| Face ID (large) | iPhone 14 Plus / 13 Pro Max / 12 Pro Max … | 1284×2778 · 1242×2688 | 上面两档都没有时才用 |
| iPhone Duo 外屏 | — | 1398×2034 | 用 iOS 27.1 SDK 及以上的 app，2027-04 起必需 |
| iPhone Duo 内屏 | — | 2007×2853 | 同上 |

> ⚠️ 这行最容易搞错：**必需的是 medium（1206×2622），不是 1320×2868**。
> 1320×2868 属于 large 档，传进 medium 槽会被判「尺寸不对」。

其余硬要求：

- **RGB，不能带 alpha 通道**。模拟器出来的是 RGBA，不转 RGB 是上传失败最常见的原因
- 单张 ≤ 8 MB；每档 1–10 张
- 首张最重要：搜索结果里只露出前两三张

重新生成（改文案就改脚本里的 `PAGES`）：

```bash
python3 .scratch/appstore/tools/compose.py       # 两档 iPhone
python3 .scratch/appstore/tools/compose_duo.py   # 两档 Duo
```

原始截图在 `assets/*.png`，由 `tools/shoot_store.py` 从模拟器抓取，演示数据靠
`DK_SEED_DEMO` / `DK_SEED_SESSION` / `DK_PREVIEW` 三个 DEBUG 环境变量拼出来。

**Duo 那两张不是从 Duo 模拟器抓的**：本机只装了 iOS 27.0 运行时，
而 `iPhone Duo` 设备类型要求更新的运行时——`simctl create` 返回 `Incompatible device`，
试 iOS 27.1 / 27.2 都是 `Invalid runtime`。所以是用 iPhone 18 Pro 的真截图
两屏并排排版的。装上 Xcode 27.1+ 运行时之后应换成真机抓图。

**已知两处不完美**

- `05-记录.png` 顶上「本周有效组 0」与「2/3 训练天」、五条 100% 的训练记录并列。
  这是演示数据只写了 Session 没写 SetLog 造成的，不是产品缺陷；补上逐组日志重拍即可
- `3-计划.png` 没有采用：页面底部浮动标签栏压在 AI 输入框上、下面「动作库 / 导入计划 / 调整」
  被裁掉一半，是真实布局问题，修好之前不进商品图

## 3. 还没有、但 Apple 一定要的
1. **隐私政策网页**。国内可放 GitHub Pages / 语雀 / 自己的域名。内容至少要写：收集什么（本机训练记录）、
   发给谁（AI 生成时发给用户配置的服务商）、怎么删（卸载即清）、联系方式
2. **支持网页**。Apple 只要求「能联系到你」，一页就够
3. **App Store Connect 的 app 记录**。需要先在 ASC 建 app（bundle id `app.dongke.ios`），
   才能上传构建
4. **上传通道**。本机没有 fastlane / Transporter / ASC API Key。一次性上架用
   Xcode → Organizer → Distribute App 最省事；要自动化再配 ASC API Key

## 4. 如果上中国区

2023 年起中国区新上架 app 需要 **ICP 备案号**（个人可备，需要域名与主体信息）。
没有备案只能先上其他区。这条要提前决定，备案要时间。

## 5. 提交流程（素材齐了之后）

```bash
# 1. 升 build 号（每次上传都要递增，同号会被拒）
#    改 project.yml 的 CURRENT_PROJECT_VERSION，然后
xcodegen generate

# 2. Archive（Release 配置）
#    自动签名下这里签的是 Apple Development，正常——分发证书要到第 3 步导出时才换上
xcodebuild -project DongKe.xcodeproj -scheme DongKe -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/dk-archive \
  -archivePath /tmp/dk-archive/DongKe.xcarchive archive \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'

# 3. 导出 ipa
xcodebuild -exportArchive -archivePath /tmp/dk-archive/DongKe.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/dk-export \
  -allowProvisioningUpdates
```

**第 2 步实测通过**（`ARCHIVE SUCCEEDED`，签的是 `Apple Development`，符合预期）。

**第 3 步在命令行会失败**，报这两条：

```
error: exportArchive No Accounts
error: exportArchive No profiles for 'app.dongke.ios' were found
```

不是配置问题，是这台机器上没有命令行的 Apple 账号凭据（Xcode 里登录了不算），
也还没有 App Store 分发描述文件。两条解法：

- **走图形（推荐第一次）**：Xcode → Window → Organizer → 选 archive → Distribute App →
  App Store Connect → Upload。GUI 有账号，会自动建 profile，顺带把包传上去
- 走命令行：先在 ASC 生成 App Store Connect API Key，导出时加
  `-authenticationKeyPath <p8> -authenticationKeyID <id> -authenticationKeyIssuerID <issuer>`，
  上传用 `xcrun altool --upload-app -f DongKe.ipa -t ios --apiKey … --apiIssuer …`

⚠️ 首次导出前要**先在 App Store Connect 建好 app 记录**（bundle id `app.dongke.ios`），
否则 profile 建不出来。这一步只能你自己做，需要你的账号。

上传后走 TestFlight 内测一轮，确认安装包、音条、通知在真机上都正常，再提交审核。

## 6. 审核时容易被挑的三处

1. **5.1.1 权限**：麦克风与语音识别的说明已经写了具体用途（不是「需要麦克风权限」这种废话），这条没问题
2. **1.4.1 健康声明**：描述里不要出现「治疗」「诊断」「康复」这类词。app 里已有 `HealthNoticeView` 免责声明，
   但**商店描述也要写一句「本应用不提供医疗建议」**
3. **AI 生成内容的边界**：用户可以输入任意文字让 AI 排计划。审核会看生成结果会不会给出危险建议
   （比如鼓励带伤训练）。如果 §1.1 走方案 A（用户自带 Key），这条压力小很多——相当于用户自己的服务
