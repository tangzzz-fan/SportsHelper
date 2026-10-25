# 上架清单

> 状态：启动屏已完成，其余按顺序推进。**先看 §1 的两条阻断项**——不解决就提交不了，
> 或者提交了会被拒/被薅。

## 0. 已经做完的（本轮）

| 项 | 结果 |
|---|---|
| 启动屏 | `UILaunchScreen` = 背景 `LaunchBackground`（浅 `#F2F2F7` / 深 `#000`）+ 居中 `LaunchMark`（`#0E7C66` / `#34B39A`），与首屏 `systemGroupedBackground` 同色，切进内容不闪 |
| Info.plist | 从 `GENERATE_INFOPLIST_FILE` + `INFOPLIST_KEY_*` 迁到 `DongKe/Info.plist`（`UILaunchScreen` 是嵌套字典，build setting 传不了）。产物逐键核对过，版本号仍由 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 注入 |
| 签名 | 顶层写死 `Apple Development` 会让 Archive 签不出来，已给 Release 配 `Apple Distribution`（本机证书 `B1147DF3…`，team `UKXWZ3FS84`） |
| 真机验证 | 已装 iPhone 16 Pro，浅/深色截图均正确 |

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
| 截图 | **6.9" 必备**（iPhone 18 Pro Max 模拟器可出，1320×2868），3–10 张 | 待拍 |
| 隐私政策 URL | **必填**，可公开访问 | **没有**，见 §3 |
| 支持 URL | 必填 | 没有 |
| 年龄分级 | 健身教学，无成人/暴力内容 → 4+ | 待填问卷 |
| App 隐私问卷 | 与 `PrivacyInfo.xcprivacy` 一致 | 取决于 §1.1 选哪条 |
| 出口合规 | `ITSAppUsesNonExemptEncryption = false`（只用 HTTPS 标准加密） | 已配 |
| 审核备注 | 说明 AI 生成需要 Key（若走方案 A），附一台不用登录的说明 | 待写 |

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

# 2. Archive（Release 配置，走 Distribution 证书）
xcodebuild -project DongKe.xcodeproj -scheme DongKe -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/dk-archive \
  -archivePath /tmp/dk-archive/DongKe.xcarchive archive \
  OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'

# 3. 导出 ipa（Xcode 27 的 method 叫 app-store-connect，旧值 app-store 仍兼容）
#    ExportOptions.plist 里写 method / teamID / signingStyle=automatic
xcodebuild -exportArchive -archivePath /tmp/dk-archive/DongKe.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/dk-export
```

之后两条路任选：

- **图形**：Xcode → Window → Organizer → 选 archive → Distribute App → App Store Connect → Upload
- **命令行**：`xcrun altool --upload-app -f /tmp/dk-export/DongKe.ipa -t ios --apiKey <key> --apiIssuer <issuer>`
  （需要先在 ASC 生成 App Store Connect API Key，本机还没有）

上传后走 TestFlight 内测一轮，确认安装包、音条、通知在真机上都正常，再提交审核。

## 6. 审核时容易被挑的三处

1. **5.1.1 权限**：麦克风与语音识别的说明已经写了具体用途（不是「需要麦克风权限」这种废话），这条没问题
2. **1.4.1 健康声明**：描述里不要出现「治疗」「诊断」「康复」这类词。app 里已有 `HealthNoticeView` 免责声明，
   但**商店描述也要写一句「本应用不提供医疗建议」**
3. **AI 生成内容的边界**：用户可以输入任意文字让 AI 排计划。审核会看生成结果会不会给出危险建议
   （比如鼓励带伤训练）。如果 §1.1 走方案 A（用户自带 Key），这条压力小很多——相当于用户自己的服务
