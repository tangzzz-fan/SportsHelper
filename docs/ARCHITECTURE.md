# 动刻 iOS 架构设计

版本：v1.5
状态：已交付并持续维护（v1.5 补会话账本与保持时间进阶，见下方修订记录）
适用范围：居家减脂运动提醒助手 iOS MVP（iPhone）
配套契约：`docs/plan-schema.json`（计划数据唯一契约）
生效顺序：`docs/FROZEN-BASELINE.md` + `docs/SPEC.md` > 本文 > `docs/PRD.md` / `docs/UIUX.md` / `docs/design-tokens.json`。冲突时以 FROZEN-BASELINE 与 SPEC 为准。
关联文档：`docs/PRD.md`（需求）、`docs/UIUX.md`（页面与视觉）、`docs/design-tokens.json`（设计 token）

修订记录：

- v1.0 首版：技术选型、分层、数据模型、计划契约、通知与训练引擎、测试策略
- v1.1 吸收 PRD 与 UIUX 的硬约束后修订：动作图示从"自绘骨架"改为"开源线稿素材"（D-20）；新增久坐提醒链路与时效性通知（§9.7）；打卡改为三态（D-26）；新增跳过并顺延的排期解析（§5.4）；新增动作线稿授权履行义务（§12.3，v1.3 已撤销）；新增埋点只落本地的说明与 `notification_delivered` 不可得的结论（§13.4）；通知权限请求时机改到引导最后一屏（D-25）
- v1.2 定稿收敛：动作库锁定 18 个 catalogId（与 `plan-schema.json` 白名单一致）；素材入包 18 动作 × 3 帧 = 54 张，新增 §12.5 文件映射表与导入流程（v1.3 已撤销）；久坐提醒移出 MVP 列 P1（§9.6），通知常驻量回到 ≤7 条、预算按此重算（§9.3）；主色裁决为深青绿 `#0E7C66`（§14.3、§14.6）；取消打包字体，改系统等宽（§14.4）；最低版本 iOS 18.0 与直连 AI 进 MVP 均确认
- v1.3 按 `FROZEN-BASELINE.md` 回同步：动作图示恢复为**自绘参数化骨架 12 关节**（决策 6，撤销 D-20 的第三方素材）、主色确认**深青绿 `#0E7C66` / `#34B39A`**（决策 11）、**跳过并顺延移出 MVP 列 P1**（§2）、**字体改零打包**（撤销 B612 Mono Bold 打包，系统等宽 + `.monospacedDigit()`）、久坐额度不再提 48 小时滚动窗口（决策 8）；§12 全章重写，§5.4 退化为 weekday 匹配
- v1.4 对齐当前实现（2026-10-25）：§4.1 / §4.2 按实际的 **framework 拆分**重写（纯逻辑在 `DongKeCore` target，不是早期草案里的 `DongKe/Domain` 目录）；§5.4 排期解析从 `ScheduleResolver` 换成 `PlanCalendar`（回答「这一次兑现的是哪一天」）；§5 / §6.1 补 `planDate` 与 `catalogId`；§10 新增余力采集（§10.5）与剂量回路（§10.6）；§11 统计口径改为按计划日归属；§15.1 必测清单补 `PlanGenerator` / `PlanCalendar` / `DoseAdjustment` / `DoseReport`
- v1.5 会话账本（2026-10-25）：§5.2 / §10.4 明确加组不改完成率分母；§11 新增 `SessionLedger` 作为会话计数唯一出处，完成率与剂量分账（ADR-0006）；§10.6 静态动作走保持时间轴（+5 秒，上限 60 秒），证据只看计划内日志

---

## 1. 范围与定位

本文是实现契约，不是方案介绍。开发按本文的点名文件、接口签名、依赖方向、范围边界执行；与本文冲突时先改本文再改代码。

产品形态：无账号、无自建后端、单机运行的 iOS App。全部数据留在设备本地。唯一的网络出口是用户自己配置的 AI 服务（OpenAI 兼容 `/chat/completions`），用户不配置时该出口关闭，粘贴导入路径完全可用。

MVP 功能闭环：

1. 启动引导问卷，产出 `UserProfile`
2. 计划获取：粘贴文本 / 粘贴 JSON / 直连 AI（BYOK）
3. 解析为结构化周计划，落库
4. 按周计划生成并维护本地通知提醒
5. 训练执行：顺序推进动作、组、次数或时长、组间休息倒计时、矢量动作图
6. 打卡，记录每组实际完成值
7. 完成率与历史

---

## 2. 版本锚定

| 项目 | 锁定值 | 依据 |
|---|---|---|
| 工具链 | Xcode 26.x（26.6 或更高） | App Store Connect 自 2026-04-28 起要求 Xcode 26+ 与 26 SDK 构建，旧工具链在上传阶段即被拒 |
| SDK | iOS 26 SDK 编译 | 同上 |
| Swift 语言 | Swift 6 language mode（严格并发检查开启） | Xcode 26 起默认可用；`ModelContext` 非 Sendable，越界访问必须在编译期被抓出来 |
| 最低部署版本 | **iOS 18.0** | 见 §3.1 覆盖率论证 |
| 依赖 | 零第三方。仅 Apple 框架：SwiftUI、SwiftData、UserNotifications、Security、Charts、Foundation、OSLog | 见 §3.2 |
| 持久化 | SwiftData（iOS 18 及以上，可用 `#Index`、`#Unique`） | 见 §3.3 |
| 图标 | SF Symbols 6（iOS 18 SDK 附带），全项目唯一图标来源 | 见 §14.1 |
| 字体 | 系统字体（SF Pro / PingFang SC / 系统等宽），零打包，倒计时与训练主数字用 `.monospacedDigit()` | 见 §14.4 |
| 动作图示 | 自绘参数化骨架，12 关节 × 3 关键帧，SwiftUI `Path` 绘制，零第三方素材 | 见 §12 |
| 通知能力 | Time Sensitive Notifications capability（`com.apple.developer.usernotifications.time-sensitive`）；不申请 Critical Alerts | 见 §9.7 |
| 埋点 | 仅本地 JSONL，无上传通道 | 见 §13.4 |

不引入 Swift Package 依赖，不引入 CocoaPods。仓库中不应出现 `Package.resolved` 中的外部包条目。

### 2.1 最低版本 iOS 18.0 的覆盖率论证

Apple 2026-06 公布的 App Store 交易设备统计：全部在用 iPhone 中 iOS 26 占 79%、iOS 18 占 14%，两者合计 93%；iOS 17 及更早合计 7%。

选择 iOS 18 而非 iOS 17 的收益：
- 可用 `#Index`、`#Unique` 宏，`SetLog` 的查询与去重不必靠代码兜底
- 避开 iOS 17 初版 SwiftData 的已知缺陷（级联删除不生效、`@ModelActor` 更新不触发视图刷新、批量操作缺失）
- 可用 `Tab` 视图、`@Previewable` 等写法，减少自造容器代码

代价：放弃约 3% 的 iOS 17 设备。结论：接受。

原与 PRD 的冲突已消解：`docs/PRD.md` §9.3 已于 v1.2 改为「最低 iOS 18.0」，与本节一致，不需要再修 PRD。16.0 的成本记录保留备查：若将来回退到 16.0，SwiftData 不可用，全量改 Core Data，约 +1 周，且失去 `#Index`/`#Unique` 与本文多处依赖的 iOS 17+ 语义。

不选 iOS 26 作为最低版本的理由：iOS 26 覆盖 79%，直接放弃 14% 的 iOS 18 用户；而 iOS 26 独占能力（AlarmKit、Liquid Glass）在本期不是刚需，AlarmKit 列入 P2。

---

## 3. 技术选型对比矩阵

评分口径：1 分最差，5 分最好。权重沿用团队决策矩阵（学习成本、生态成熟度、部署成本为高权重）。

### 3.1 UI 框架

| 方案 | 学习成本 | 生态成熟度 | 部署成本 | 与系统能力契合 | 总分 | 结论 |
|---|---|---|---|---|---|---|
| SwiftUI（选中） | 5 | 5 | 5 | 5 | 20 | 声明式、零依赖、与 SwiftData / UserNotifications / Charts 同源 |
| UIKit + 手写布局 | 3 | 5 | 5 | 4 | 17 | 倒计时与动画要手写 CADisplayLink 与 Auto Layout，代码量翻倍 |
| Flutter | 2 | 4 | 3 | 2 | 11 | 通知、Keychain、HealthKit 类能力仍需写 platform channel，等于两套技术栈 |
| React Native | 2 | 4 | 3 | 2 | 11 | 同上，且矢量动画性能受桥接层影响 |

落地约束：SwiftUI 之上允许一处 UIKit 桥接——`UIApplicationDelegateAdaptor` 挂 `UNUserNotificationCenterDelegate` 与设置 `isIdleTimerDisabled`。除此外不写 UIKit 视图。

### 3.2 持久化

| 方案 | 学习成本 | 生态成熟度 | 部署成本 | 迁移与查询能力 | 总分 | 结论 |
|---|---|---|---|---|---|---|
| SwiftData（选中） | 4 | 3 | 5 | 4 | 16 | 与 SwiftUI 声明式绑定，`#Index`/`#Unique` 够用；限制见下方坑 |
| Core Data | 2 | 5 | 5 | 5 | 17 | 能力更强但样板代码多，MVP 数据量用不满它的复杂度 |
| SQLite + GRDB | 3 | 4 | 4 | 4 | 15 | 需引入第三方包，违反零依赖 |
| JSON 文件 + 内存 | 5 | 5 | 5 | 1 | 16 | 打卡记录会增长到数百行，无索引的全量读写迟早卡住 |

选 SwiftData，同时用两条设计规避它的已知坑：计划存 JSON 文档列（§6.2），不做深层关系链；不引入 `@ModelActor`，所有写操作留在主线程上下文（单次写入量极小，主线程完全吃得下）。

### 3.3 通知

| 方案 | 可靠性 | 系统限制 | 实现成本 | 结论 |
|---|---|---|---|---|
| UserNotifications + `UNCalendarNotificationTrigger(repeats: true)`（选中） | 高，App 被杀死仍触发 | 单 App 最多 64 条待触发，重复触发器只占 1 条 | 低 | 7 个星期各一条重复触发器，总量 7 条，永久不撞上限 |
| `UNTimeIntervalNotificationTrigger` 逐条排 8 周 | 中，队列排满后静默丢弃 | 8 周 × 7 天 = 56 条，再加休息计时就用满 64 | 中 | 无必要地消耗预算 |
| 后台刷新 + 本地重建 | 低 | `BGAppRefreshTask` 不保证调用时机 | 高 | 只能作为补充，不能作为主方案 |
| 远程推送 | 高 | 需服务端，违反无自建后端 | 高 | 排除 |

关键事实（Apple DTS 工程师在开发者论坛确认）：待触发本地通知上限为每 App 64 条，系统保留最先触发的 64 条并静默丢弃其余，`add()` 不返回错误。设计上必须让通知条目数远低于上限，并把重建时机写死（§9）。

### 3.4 计划解析

| 方案 | 召回率 | 可控性 | 可测性 | 结论 |
|---|---|---|---|---|
| 严格 JSON 解码（选中，主路径） | 高（AI 输出按 Schema 约束） | 高 | 高，纯函数 | 主路径。AI 直连与用户粘贴同一份 Schema |
| 自由文本启发式（选中，次路径） | 中（60%–80%） | 中 | 高，纯函数 | 中文口语表述的兜底，解析不出的字段留空交给人工校正 |
| 端上小模型推理 | 未知 | 低 | 低 | MVP 排除，模型体积与冷启动不可接受 |
| 服务端解析 | 高 | 高 | 中 | 违反无自建后端 |

四级降级链路见 §8。

### 3.5 矢量动作图

| 方案 | 视觉表现 | 包体积 | 授权义务 | 实现工作量 | 可访问性 | 总分 | 结论 |
|---|---|---|---|---|---|---|---|
| 参数化骨架 + SwiftUI Shape/Path，12 关节 + 3 关键帧（选中） | 中，线稿人形；12 关节能表达躯干角度与前后肢遮挡 | 约 40–60KB JSON | 无 | 中：渲染器一套 + 18 动作手标坐标 | 可加描述 | 17 | **选中**（FROZEN 决策 6）。零授权义务，动作数据完全可控，扩动作只加 JSON |
| 开源动作线稿 3 帧 + PDF 矢量入包（否决） | 高，真实动作线稿 | 约 0.7–1.2MB（54 张 PDF） | CC BY-SA 4.0：署名 + 许可证链接 + 变更声明，且 share-alike 与商店分发 DRM 的相容性需法务确认 | 低，只做渲染与帧序 | 可加描述 | 15 | **否决**。授权不确定性一旦落地就是整体回退，不能放到第 2 周才发现 |
| Lottie | 高 | +2.5MB SDK | 无 | 中，但需 After Effects 链路 | 差 | 11 | 违反零依赖，美术链路本团队没有 |
| 逐动作手写 Path | 中 | 0 | 无 | 极高 | 中 | 9 | 动作数一多就是维护泥潭 |
| SVG 直接渲染 | 高 | 低 | 同上 | 中 | 差 | 8 | iOS 不原生渲染 SVG，必须转换，等于绕一圈回到上一种 |
| 短视频 | 高 | 高 | 视素材 | 中 | 差 | 8 | PRD 已定后置 |

结论：**自绘参数化骨架**（FROZEN-BASELINE 决策 6）。否决素材不是工程质量问题，是授权：CC BY-SA 4.0 的 share-alike 与 App Store 分发 DRM 的相容性工程无法拍板，一旦法务否决就要 54 张图整体作废、回退成本 5–8 人日。骨架方案的手工成本在 §12.2 核算，靠「一套渲染器 + 数据」压到可控。

### 3.6 AI 调用

| 方案 | 可控性 | 兼容性 | 结论 |
|---|---|---|---|
| `URLSession` + `POST {base}/chat/completions` + `response_format: json_schema`（选中主线） | 高 | 仅支持 Structured Outputs 的服务 | 首选，一次成功率最高 |
| 同级降级：`response_format: json_object` | 中 | 支持 JSON mode 的服务 | 服务端返回 400 不支持 json_schema 时自动降级 |
| 再降级：纯提示词要求输出 JSON | 低 | 全部兼容 | 最后一级，靠 `PlanJSONExtractor` 从自由文本里抠 JSON |
| 官方 SDK | — | — | 无 Swift 官方 SDK，且会引入依赖，排除 |

不启用流式。理由：一次计划生成输出 2–6KB，非流式等待 5–20 秒可接受；流式要处理 SSE 分帧、断线续传，MVP 收益低于成本。UI 用进度指示 + 可取消。

### 3.7 依赖策略

零第三方。不允许出现 `Package.resolved` 外部条目、Podfile、Carthage。任何"要不要加个库"的讨论，默认答案是不加，除非 Apple 框架确实无法完成且写明替代成本。

---

## 4. 分层架构与目录结构

### 4.1 分层与依赖方向

分层不是文件夹约定，是**两个 target**：

```
DongKeCore（framework）
  纯 Foundation。模型 / 解析 / 计划生成 / 剂量规则 / 状态机 / 动作图 / 端口协议
  不知道 UIKit、不知道 SwiftUI、不知道 SwiftData、不知道用户通知
        │  import
        ▼
DongKe（app）
  App（装配） → Features（视图） → Data（SwiftData） → Services（系统能力）
                    └──→ DongKeCore ←──┘
```

把纯逻辑切进一个独立 framework 的理由是可测性，不是洁癖：`DongKeCoreTests` 只链 `DongKeCore` 与 Foundation，跑 700 条单测两秒钟，不起模拟器、不建 `ModelContainer`。留在这个 target 里的东西必须能在纯内存里判定。

硬规则：

| # | 规则 |
|---|---|
| 1 | `DongKeCore` 只 import Foundation（`@Observable` 状态机可 import Observation）。禁止 SwiftUI / SwiftData / UserNotifications / UIKit |
| 2 | `DongKe/Data` import Foundation + SwiftData + DongKeCore。禁止 import SwiftUI |
| 3 | `DongKe/Services` import Foundation + 系统框架 + DongKeCore。禁止 SwiftUI（唯一例外 `LargeTextStore`）、禁止 SwiftData |
| 4 | `DongKe/DesignSystem` import SwiftUI + DongKeCore（只读模型用于展示） |
| 5 | `DongKe/Features` import SwiftUI + DongKeCore + DesignSystem + Services。**禁止直接 import SwiftData**——持久化只经 `Data/` 的 Store |
| 6 | `DongKe/App` 是唯一装配点，负责创建 `ModelContainer`、Store 实例、注入到 View 树 |
| 7 | 依赖只能向下。Features 与 Services 之间不互相 import；两者通过 `DongKeCore/Ports/` 的协议解耦 |
| 8 | 端口协议放在 `DongKeCore/Ports/`（`AIPlanGenerating` / `SecretStoring` / `SpeechAnnouncing`），实现放在 `Services/` |

第 5 条是这套分层的关键：视图层不碰 `ModelContext`，于是「这条规则什么时候会说话」这类判断题全部落在 `DongKeCore` 里，能被单测钉住，而不是散在 `body` 里靠人肉回归。

> v1.4 修订：早期草案把纯逻辑放在 `DongKe/Domain/` 目录，实际做成了独立 framework `DongKeCore`。目录名换了，依赖方向与第 5 条不变。

### 4.2 目录结构（点名到文件）

```
DongKeCore/                            # framework：纯 Foundation，可脱离模拟器测
├── Models/                            # 领域模型与动作库，全部 Codable + Sendable
│   ├── PlanModels.swift               # WorkoutPlan 聚合根 / PlanDay / ExerciseBlock / ExercisePrescription / PlanMeta
│   ├── ProfileModels.swift            # UserProfile（引导问卷产物，也是 AI 提示词输入）
│   ├── SessionModels.swift            # SetLog / SetStatus / SkipReason / ReminderSettings
│   ├── SetTarget.swift                # 次数 / 时长 / 距离三选一
│   ├── Weekday.swift                  # 自有序 monday=1...sunday=7
│   ├── TimeOfDay.swift
│   ├── ExerciseCatalog.swift          # 动作库入口、按 id 与别名查询、主导肌群映射
│   ├── ExerciseCatalogLower/Upper/Core.swift
│   ├── ExercisePurpose.swift / Muscle.swift / BodyPart.swift / ExerciseMergeMap.swift
│   └── ParseModels.swift
├── Parsing/                           # 文本 → 草稿
│   ├── PlanJSONExtractor.swift        # 从任意文本抠出 JSON 片段
│   ├── PlanDecoder.swift              # JSON → WorkoutPlan，错误定位到字段路径
│   ├── PlanValidator.swift            # 取值范围与一致性校验
│   ├── PlanNormalizer.swift           # 排序、去重、clamp、补默认
│   ├── FreeTextPlanParser.swift       # 自由文本启发式
│   ├── PlanImportService.swift        # 四级链路调度：strictJSON → lenientJSON → 表格 → 逐行
│   └── PlanSafetyChecker.swift        # 不适部位 → 冲突动作 / 推荐动作
├── Import/                            # 归一化与纠错记忆
│   ├── PlanDraft.swift / PlanDraftParser.swift / PlanDraftCompiler.swift
│   ├── DraftLineScanner(+Text/+Dose/+Aliases).swift
│   ├── DraftTableAdapter.swift / DraftJSONAdapter.swift
│   ├── ExerciseAliasResolver.swift / AliasMemory.swift / TextNormalization.swift
│   └── CorrectionMemory.swift / UserExercise.swift
├── Scheduling/
│   ├── PlanGenerator.swift            # 本地生成：动作选取、组数预算、日名与内容一致
│   ├── PlanCatalog.swift              # 生成池，从 ExerciseLibrary 派生（不另维护清单）
│   ├── PlanCalendar.swift             # 「今天该练哪一节」「这一次兑现的是哪一天」
│   ├── HistoryStats.swift             # 周进度 / 连续天数 / 有效组 / isDone
│   ├── DoseReport.swift               # 记录页读数：有效组、肌群分布、跳过原因
│   ├── WeeklyScheduleGenerator.swift / NotificationPlan.swift
│   └── ReminderTrigger.swift / ReminderHealth.swift
├── Workout/
│   ├── WorkoutFlowModel.swift         # 计划 → [FlowStep] 线性序列（含「每项最后一组」判定）
│   ├── RestTimerStateMachine.swift / SetTimerStateMachine.swift / SetTimerDriver.swift
│   ├── DoseAdjustment.swift           # 入口、常量、apply / restoreProposal
│   ├── DoseAdjustment+Safety.swift    # 疼
│   ├── DoseAdjustment+Reduction.swift # 换动作、太累、没时间
│   ├── DoseAdjustment+Progression.swift # 三周加一降、加量（强证据 + 余力）
│   ├── DoseContext.swift / PlanProposal.swift / ProposalMemory.swift
│   ├── WorkoutCheckpoint.swift        # 断点 + 30 分钟窗口
│   ├── SessionLedger.swift            # 会话分账：计划内 / 额外、完成率与有效组口径
│   ├── SessionRecap.swift             # 账本投影 + 时长文案
│   ├── ProgressionAxis.swift          # 进阶轴：次数 / 保持时间，距离无轴
│   └── WorkoutAnnouncement*.swift / SpeechCueCoordinator.swift / WorkoutVoiceSession.swift / WorkoutPrompt.swift
├── AI/                                # BYOK 客户端、提示词、响应映射
├── VoiceInput/                        # 语音输入状态机与文案
├── Figure/                            # GeneratedFigureData.swift（3MB 生成数据，勿手改）
└── Ports/                             # AIPlanGenerating / SecretStoring / SpeechAnnouncing

DongKe/                                # app
├── App/
│   ├── DongKeApp.swift                # @main，只做 Scene 装配
│   └── RootView.swift                 # 引导完成与否的分流
├── Data/
│   ├── Persistence/                   # 5 张 @Model + 5 个 Store
│   │   ├── PlanEntity / PlanStore
│   │   ├── SessionEntity / SessionStore
│   │   ├── SetLogEntity / SetLogStore
│   │   ├── ProfileEntity / ProfileStore
│   │   └── UserExerciseEntity / UserExerciseStore
│   ├── SamplePlan.swift               # 预览样本数据 + 日期 → Weekday 换算
│   ├── SessionSummary.swift           # 会话的展示态（带 planDate）
│   ├── WorkoutCheckpointStore.swift   # 断点持久化
│   ├── AliasMemoStore.swift / CorrectionStore.swift / ProposalMemo.swift
│   └── DataResetService.swift
├── DesignSystem/
│   ├── Theme.swift / Typography.swift / Icons.swift
│   ├── GlassSurface.swift             # Liquid Glass 双路径（iOS 26 原生 / iOS 18 近似）
│   └── LargeTextFloor.swift
├── Features/
│   ├── Shell/AppShell.swift           # 唯一的标签装配与训练全屏入口
│   ├── Onboarding/                    # 5 屏问卷
│   ├── Today/                         # 今日页 + 卡片（含「这一节练过没有」）
│   ├── Workout/                       # 训练执行、动作图、倒计时、会话状态
│   ├── Rest/                          # 组间休息
│   ├── Summary/                       # 完成总结
│   ├── History/                       # 记录页（DoseReport 的展示层）
│   ├── Plan/                          # 周计划、日详情、提案卡、手动调整、AI 快捷入口
│   ├── Import/                        # 粘贴、说一句、校对页
│   ├── Library/                       # 动作库与动作详情
│   └── Settings/
├── Resources/ai-defaults.json          # 内置 AI 端点与模型默认值
└── Services/
    ├── NotificationService.swift / NotificationRouter.swift / ReminderSettingsStore.swift
    ├── AIPlanClient.swift / AISettingsStore.swift / KeychainService.swift
    ├── VoiceService.swift / VoiceInputService.swift / SystemSpeech*.swift / ScriptedSpeechTranscriber.swift
    └── DaySkipStore.swift / LargeTextStore.swift / Haptics.swift

Shared/A11yIdentifiers.swift           # VoiceOver 词汇；DongKe 与测试共用，不入 Core
DongKeCoreTests/                       # 只链 DongKeCore，纯内存跑
```

动作库不在 `Resources/*.json`，而是编译进 `DongKeCore/Models/ExerciseCatalog*.swift` 的 Swift 常量——库是只读的，放进 bundle 只会多一条「文件没打进去」的失败路径，且编译期就能查出名字写错。图示数据同理，`GeneratedFigureData.swift` 是生成产物（生成器在 `.scratch/figure-and-glass/tools/`，手动跑，不进构建）。

### 4.3 文件组织硬规则

| # | 规则 | 不合格表现 |
|---|---|---|
| 1 | 单文件不超过 **500 行**（不含空行）。超限按子功能拆文件 | 一个 `WorkoutView.swift` 800 行 |
| 2 | 一个文件一个主导出、一个主职责 | 模型 + 解析 + 校验塞在一个 `Plan.swift` |
| 3 | 一个视图一个文件；同屏子视图超过 2 个拆分到独立文件 | `body` 里 200 行嵌套 |
| 4 | ViewModel 不 import SwiftUI（只用 Observation 与 Foundation） | ViewModel 里写 `Color`、`Font` |
| 5 | ViewModel 不出现 `modelContext`、`FetchDescriptor` | Feature 层直接查库 |
| 6 | `Domain` 下无任何 I/O、无 `Date()` 直读、无 `Timer` | 状态机里 `Date()` 卡死测试 |
| 7 | 生产代码注释数为 0（含 `// MARK:`）。解释写进本文与测试名 | 文件里出现 `// 这里先这样` |
| 8 | 不硬编码颜色与字号，一律走 `Theme` / `Typography` | `Color(hex: "#0E7C66")` 散落视图 |
| 9 | 不使用字面量 `Image(systemName:)`，一律走 `Icons` | 视图里直接写 `"figure.walk"` |
| 10 | 不使用 emoji 作为功能图标或装饰 | 用 emoji 当按钮图标 |

门禁命令（CI 与本地提交前各跑一次，任一非空即退回）：

```bash
grep -rn "import SwiftData" DongKe --include=*.swift | grep -v "/Data/" | grep -v "/App/"
grep -rn "import SwiftUI" DongKe/Services DongKe/Data --include=*.swift | grep -v "Services/LargeTextStore.swift"
grep -rn 'Image(systemName: "' DongKe --include=*.swift
grep -rn "Color(hex:" DongKe --include=*.swift | grep -v "DesignSystem/Theme.swift"
grep -rln "//" DongKe --include=*.swift | xargs -r grep -Hn "^\s*//"
for f in $(find DongKe DongKeCore DongKeCoreTests Shared -name '*.swift'); do n=$(grep -cve '^[[:space:]]*$' "$f"); [ "$n" -gt 500 ] && echo "$n $f"; done; true
grep -rn "URLSession" DongKe --include=*.swift | grep -v "Services/AIPlanClient.swift"
grep -rn "UIPasteboard" DongKe --include=*.swift | grep -vE "UIPasteboard\.general\.string[[:space:]]*="
grep -rn "removeAllPendingNotificationRequests" DongKe --include=*.swift
grep -rn "#[0-9A-Fa-f]\{6\}" DongKe --include=*.swift
```

最后四条 grep 的期望结果为空，各自对应一条架构承诺：

- `URLSession` 只允许出现在 `AIPlanClient` 里。这是"离线优先"唯一可自动验证的形式
- `UIPasteboard` 只允许**写入**（`= ` 赋值，用于复制提示词）；读取粘贴板一律走 `UIPasteControl`，普通读取会被上面这条 grep 拦下
- `removeAllPendingNotificationRequests` 一律不出现，通知只能按前缀清理，见 §9.5
- 任何 6 位十六进制色值都不出现，颜色只能来自 `design-tokens.json`

> 门禁两处修订（2026-10-24）：`systemName:` 那条原写法会连 `Image(systemName: Icons.x)` 一起拦（永远非空，等于失效），改为只查**字面量**；`UIPasteboard` 那条原写法连写剪贴板也拦，但复制提示词没有替代 API，改为只拦读取。
>
> 门禁两处修订（2026-10-25）：`find` 的目录去掉已删除的 `DongKeUITests`；`import SwiftUI` 那条去掉不存在的 `DongKe/Domain`（本项目的 Domain 在 `DongKeCore`），并放行 `Services/LargeTextStore.swift`——它用 `DynamicTypeSize` 定义大字模式下限，那个类型来自 SwiftUI，而这条规则针对的是 ViewModel 不碰视图类型，不是禁止 store 引用字号枚举。

> 门禁修订（2026-10-25）：单文件上限 300 → **500 行**。原命令用 `wc -l`（含空行）统计，与「不含空行」的定义不一致，且只扫 `DongKe/`、漏了 `DongKeCore/` 与两个测试 target——三个问题一起改掉，改成逐文件 `grep -cve '^[[:space:]]*$'` 并扫全部源码目录。

任一 grep 非空，或存在超 500 行的文件、入口文件含业务逻辑，即退回重做，不算完成。

---

## 5. 领域模型

全部为 `Codable + Equatable + Sendable` 的 struct 或 raw-value enum。JSON 编解码字段名与 `plan-schema.json` 一致（计划相关模型直接复用契约字段名，避免两套命名互相映射）。

| 模型 | 关键字段 | 说明 |
|---|---|---|
| `Weekday` | `monday=1 ... sunday=7` | **不用** Foundation 的 `Calendar` weekday 语义（那里 1 是周日）。与系统互转统一走 `Weekday.systemWeekday`，实现为 `(mondayBasedIndex % 7) + 1` |
| `TimeOfDay` | `hour: Int`, `minute: Int` | 表示"每天 19:30"，不用 `Date`。`Date` 会带上无关的日期与时区信息 |
| `UserProfile` | heightCm, weightKg, age, sex, goal, level, availableWeekdays, sessionMinutes, equipment, injuries, onboardedAt | 引导问卷产物，也是 AI 提示词的输入 |
| `WorkoutPlan` | id, schemaVersion, meta, days(7), cautions, source, createdAt, updatedAt | 聚合根。`source` 为 `.ai / .pasteJSON / .pasteText / .manual` |
| `PlanMeta` | title, goal, level, daysPerWeek, sessionMinutes, notes | 列表展示与再次生成上下文 |
| `PlanDay` | dayIndex, weekday, isRestDay, title, scheduledTime(TimeOfDay?), estimatedMinutes, blocks, notes | 恒有 7 条，休息日占位 |
| `ExerciseBlock` | blockId, kind, title, rounds, restBetweenItemsSec, restBetweenRoundsSec, items, notes | `kind` 表达热身/主训练/循环/超级组/放松，`rounds` 表达循环与超级组轮数 |
| `ExercisePrescription` | itemId, catalogId, name, sets, target, restSec, tempo, load, notes | 单动作处方 |
| `SetTarget` | type(.reps/.durationSec/.distanceM), value, perSide | 次数 / 时长 / 距离三选一，`perSide` 区分每侧 |
| `Load` | type, value | 负重类型与单只重量 |
| `ExerciseEntry` | id, name, group, equipment, isStatic, cues, mistakes, regressionName / regressionId, alternativeId, affectedParts, relievedParts, purposes | 只读，编译进 `ExerciseCatalog*.swift`（§4.2）。字段口径见 §5.6 |
| `WorkoutSession` | id, planId, planDayId, startedAt, finishedAt, status, plannedSets, completedSets, totalRestSeconds | 运行期的值对象。**落库的是 `SessionEntity`**（§6.1），两者字段不同：表里多 `planDate` 与 `title` |
| `SetLog` | id, sessionId, prescriptionId, catalogId, setIndex, status, plannedValue, actualValue, skipReason, rpe, completedAt | 一组一条。**status 三态**：`done` / `downgraded`（降阶完成）/ `skipped`。`prescriptionId` 只在当前这版计划内有效，跨版本统计动作要用 `catalogId` |
| `SetStatus` | `done` / `downgraded` / `skipped` | 三态是 PRD 的硬要求，不用 `isSkipped: Bool`（布尔表达不了「降阶完成」） |
| `SkipReason` | `noTime` / `tooHard` / `pain` / `noEquipment` / `other` | 跳过原因枚举。`pain` 单独一档，用于后续风险提示，不参与完成率 |
| `ReminderSettings` | workoutEnabled, leadMinutes, sedentaryEnabled, sedentaryIntervalMinutes, sedentaryWindow, sedentarySnoozeLimit, soundEnabled, overrideTimes | 两类提醒分开开关，不塞进一个 enabled |
| `ReminderSpec` | id, kind(`workout` / `sedentary` / `rest`), fireComponents, title, body, interruption, priority | 纯值对象，由 `ReminderPlanBuilder` 产出，交给 `NotificationService`。`fireComponents` 直接就是 `DateComponents`，不在服务里二次组装 |

早期草案为 P1 预留过 `ownerId` / `updatedAt` / `ScheduleAdjustment` / `SedentaryWindow` / `AnalyticsEvent`，实现时全部没有保留。理由一致：**没人读的字段与类型只会腐烂**，而 P1 真要接时按那一版 schema 重写，比维护一份猜出来的占位更省事。本 App 没有账号、没有同步、没有上传通道，所以也不存在「待同步」这类状态。

### 5.1 为什么动作库不进数据库

动作库是只读常量，43 条，编译进 `DongKeCore/Models/ExerciseCatalog*.swift`（§4.2）。放进 SwiftData 只会引入「首次启动播种失败」这类失败模式，收益为零：库是只读的，没有查询需求，也没有用户改它的需求。`ExerciseLibrary` 提供按 id / 按别名查询，全部是静态方法，不持有状态。

**用户自定义动作是唯一的例外**：`UserExerciseEntity` 进库（可增删改），因为它由用户产生、要跨会话保留、且被计划的 `catalogId` 引用。库内动作与自定义动作在模型上是两条路——`ExerciseEntry` 是编译期常量，`UserExercise` 是运行期记录。

### 5.2 `WorkoutFlowModel`：把计划展开成线性执行序列

训练页不能直接遍历三层嵌套结构，要一个线性序列驱动"当前第几个动作第几组"。`WorkoutFlowModel(plan:)` 在进入训练时一次性展开为 `[FlowStep]`：

```
FlowStep
├── .set(prescriptionId, setIndex, target, restAfterSec)   # 完成这一组后给 restAfterSec 秒休息
├── .roundBreak(seconds)                                   # 循环块换轮的休息
├── .blockBreak(seconds, nextBlockTitle)                    # 换块的提示
└── .finished
```

循环块展开规则：`rounds` 轮，每轮依次走 `items`，轮内动作间用 `restBetweenItemsSec`，每轮结束插一条 `.roundBreak(restBetweenRoundsSec)`（最后一轮不插）。超级组同理（`restBetweenItemsSec = 0`）。`plannedSets` 等于展开后 `.set` 的数量，写进 `WorkoutSession` 作为分母，完成率分母从此固定：改计划不影响历史，**会话中加组也不改它**（额外组另记来源，见 §11.1）。

这是纯函数，输入 `WorkoutPlan`，输出 `[FlowStep]`，必须单测（含：循环块、超级组、休息为 0、单动作日、休息日）。

### 5.4 排期：`occurrence` 回答「这一次兑现的是哪一天」

FROZEN-BASELINE §2 把「跳过并顺延」列为本期不做，所以本期没有偏移队列，只有两个纯查询：

```swift
public struct PlanOccurrence: Equatable, Sendable {
    public var dayIndex: Int
    public var date: Date
}

public enum PlanCalendar {
    static func occurrence(on date: Date, in plan: WorkoutPlan, calendar: Calendar) -> PlanOccurrence?
    static func occurrence(of dayIndex: Int, anchoredAt date: Date, in plan: WorkoutPlan, calendar: Calendar) -> PlanOccurrence?
}
```

| 函数 | 回答 | 用在哪 |
|---|---|---|
| `occurrence(on:in:)` | 今天该练哪一节：今天是训练日就是今天，否则向后找**下一个**训练日（最多 7 天，可跨周） | 今日页卡片、开始按钮、结束页「本周 x/y」 |
| `occurrence(of:anchoredAt:in:)` | 这一节（按 `dayIndex`）离锚点最近的那一天是哪天 | 通知深链、断点续练 |

三条硬约束：

- 入参只有日期与计划，纯函数、无状态、无副作用；`nil` 表示「计划里没有训练日」或「`dayIndex` 指向休息日」
- **卡片与按钮必须调同一个函数**。这一条是踩出来的：以前卡片按「下一个训练日」算、启动按「本周第一个训练日」算，于是周二休息日卡片写「下次训练 周三」，点下去开的是已过去的周一那节
- 日期到 `weekday` 的换算必须走 `Weekday(systemWeekday:)`，不许各处自己算（Calendar 的 `weekday` 是 1=周日，计划的 1=周一，这条最容易写反）

「哪一天」不是展示细节，它是账本的主键：会话把 `planDate` 写成这个 `date`，周进度与「这一节练过没有」都按它数（§11）。所以提前练一节，账记在**那一节本来的日期**上，而不是点按钮的那天。

P1 接回时的设计结论保留备查：把计划当不可变模板，偏离单独记 `ScheduleAdjustment`（`skipAndShift` / `skipOnly`），由 `resolveDay(on:plan:adjustments:calendar:)` 算出某天该练哪份计划日；连续跳过超过一个完整周期时顺延队列清空并回落到原始模板，避免无限漂移。本期的签名是它的退化形式（`adjustments` 恒为空），P1 加一个参数即可，调用方不改。

### 5.5 三张表分离的执行约束

计划（模板）/ 会话（本次实际）/ 每组日志（已完成历史）三者的写入权限严格分离：

| 表 | 可写时机 | 禁止 |
|---|---|---|
| `PlanEntity` | 用户显式保存、采纳提案、切换、删除 | 训练过程中被任何代码修改 |
| `SessionEntity` | 会话未结束时改计数与 `finishedAt` | 结束后只读 |
| `SetLogEntity` | 仅追加；`undo` 仅允许删除**当前未结束会话**的最后一条 | 修改已结束会话的任何日志；按 id 修改已完成记录 |

「改今天的一组」由此天然被约束在追加与未结束会话的末条删除范围内，物理上碰不到昨天的历史，也碰不到计划模板。这一条由 `SetLogStore` 的前置断言保证，有单测覆盖「对已结束会话调 undo 必须抛错」。

三张表之间**没有 `@Relationship`**，只有普通字段（`sessionId`）关联。理由见 §6.3。

### 5.6 动作库字段口径

代码里不写注释，字段语义全部收在这里。改这些字段前先读本节。

| 字段 | 口径 |
|---|---|
| `affectedParts` | **只标主要负荷**——发力肌群和承受大部分体重的关节。稳定肌、姿势代偿不算。理由：标宽了，用户一说「腰不好」整张表都会被禁掉，计划直接没法生成 |
| `regressionId` | 低阶替代。指向库内动作时必须是另一条，不能指向自己；为空则只显示 `regressionName` 文案。**这是「同一个动作更轻的做法」，不负责绕开部位** |
| `alternativeId` | 换动作：库内**完全绕开**本动作负荷部位的另一条动作。`PlanSafetyChecker` 只在目标动作与不适部位不相交时采用，否则回退到 `regressionName`。与 `regressionId` 是两种语义，不能互借：深蹲的降阶是靠墙静蹲（同样用膝），换动作是臀推（不用膝） |
| `relievedParts` | 这个动作对哪个部位**有帮助**，与 `affectedParts` 互补而非重叠。只有康复向动作会标，普通训练动作留空。`PlanSafetyChecker.reliefs` 推荐时**额外要求 `affectedParts` 与不适部位不相交**——一个动作不能既被推荐又让同一部位吃力 |
| `purposes` | 默认 `[.strength]`。区块取词：`warmup` 只取含 `.warmup` 的，`cooldown` 只取含 `.stretch` 的。一个动作可以多用途——开合跳既能热身也能当低强度有氧。康复动作标 `[.mobility]`：**不含 `.strength` 就不会进生成器的力量池**，这是它们不被排进主训练的唯一机制 |
| `isStatic` | 静力保持动作。数据上仍有 3 帧，渲染期只取第 1 帧 |

**部位词表只有一个来源**：`BodyPart.keywords`。`PlanBriefParser` 的避让识别、`PlanSafetyChecker` 的校验、`PlanCatalog` 的排除都从它派生（`BodyPart.avoidVocabulary` 是它按长度降序的投影，长词优先，「肩颈」不会被「肩」先吃掉）。曾经这三处各维护一张词表，结果生成器避开的动作和校验器标出的不是同一批。

**动作名归一化放在 `PlanImportService.parse` 外层，不在各 decoder 里。** `strictJSON` 走 `PlanDecoder` 直接解出整份计划，根本不经过 `PlanDraftCompiler`；只有在外层才一次覆盖 strictJSON / lenientJSON / freeText 三条路径。库外动作（`custom_` 前缀）没有标准名可归，保留原名。

**图示的 `stroked` 只为一件事存在**：素材走 `fill`（path 本身是闭合轮廓，靠 `evenodd` 出线条），自绘骨架走 `stroke`（path 是关节与轮廓线，描边才看得见）。当前生成数据里没有 `stroked: true` 的条目，这个分支是为 §12 的生成方案留的入口。

---

## 6. 持久化设计

### 6.1 表结构

**两种存储，一条判据**：跨会话要对账的进 SwiftData，其余进 UserDefaults。

| 进 SwiftData | 为什么 |
|---|---|
| 计划、档案 | 各一条，JSON 文档列；被会话引用，要能整体读出 |
| 会话、每组日志 | 历史账本，要按日期、按动作、按会话查询 |
| 自定义动作 | 被计划引用 |

| 进 UserDefaults | 为什么 |
|---|---|
| 提醒设置 / 跳过记录 / 断点 / 提案记忆 / 别名记忆 / 纠错记忆 | 单条小状态，没有查询需求，丢了不影响历史账本。代价是**没有 schema 迁移**，只能靠「解不出来就用默认值」兜底 |

**PlanEntity**（单行，`key` 固定 `"activePlan"`）

| 字段 | 类型 | 说明 |
|---|---|---|
| key | String | `#Unique` |
| payload | Data | **完整 `WorkoutPlan` 的 JSON**，与 `plan-schema.json` 同构 |
| updatedAt | Date | 保存时刻 |

**ProfileEntity**（单行，`key` 固定 `"profile"`）：同样是 `key / payload / updatedAt` 的 JSON 文档形态。它只在生成计划与拼提示词时整体读出，不是查询维度，所以没有理由拆成显式列。

**SessionEntity**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | `#Unique` |
| startedAt | Date | 会话开始 |
| finishedAt | Date? | 未结束为 nil |
| title | String | 冗余列，展示用 |
| plannedSets / completedSets | Int | 分母在开始时固定 |
| **planDate** | **Date?** | **这一次兑现的是哪一天**，由 `PlanCalendar` 算出（§5.4）。旧数据为 nil，读时回落到 `startedAt` 的日历日 |

`planDate` 是唯一能回答「这一节练过没有」的字段。没有它，提前练无法归属、训练日无法去重、结束页说不出「本周到哪儿」。

**SetLogEntity**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | `#Unique` |
| sessionId | UUID | 属于哪次会话 |
| prescriptionId | String | 计划内的处方 id（如 `1-main-2`），**计划改版后与动作对不上** |
| **catalogId** | **String?** | **动作库 id**。跨计划版本统计某个动作时必须用它 |
| setIndex | Int | 该动作的第几组 |
| statusRaw | String | `done` / `downgraded` / `skipped` |
| plannedValue / actualValue | Int | 目标与实际 |
| skipReasonRaw | String? | `skipped` 时必填 |
| completedAt | Date | 落盘时刻。`recentLogs()` **按它倒序**返回，取「某动作最后一组」要用 `max(by: setIndex)`，不能用 `.last` |
| rpe | Int? | 1–5，只在每个动作的最后一组采集（§10.5） |

**UserExerciseEntity**：`exerciseId`（`#Unique`）+ 名称 / 分组 / 器械 / 是否静态 / 默认组数 / 默认值 / 休息秒。

---

### 6.2 为什么计划存 JSON 文档列

三点理由，都不是偏好而是有代价的判断：

1. **契约已经在手**：AI 输出、粘贴导入、备份导出都需要 `WorkoutPlan` 的 JSON。再拆成 6 张关系表，等于同一份结构维护两套映射，回归面翻倍。
2. **计划是文档，不是事实表**：一个计划内部结构强耦合（块 → 动作 → 目标），没有跨计划的按动作聚合查询需求。需要的是"整份读出、整体替换"，这正是文档存储的形状。
3. **规避 SwiftData 的已知缺陷**：`Plan → PlanDay → ExerciseBlock → ExercisePrescription` 是四层 to-many 链。SwiftData 在多关系上的级联删除存在"不删除关联数据"的已知问题，深层链上更容易触发。扁平化后，删除一个计划就是删一行。

代价与对策：无法用 SQL 直接查"所有计划里深蹲的总组数"。当前没有这个需求；若将来有，用 `payload` 全量解码后内存聚合（计划数量是个位数）。这一条写进 §18 的技术债清单，不提前优化。

**没有冗余列，所以不存在「JSON 与列不一致」。** 早期草案在计划表上放了 `title` / `daysPerWeek` / `goal` 三个冗余列供列表排序，实现时删掉了——库里只有一份计划，标题从解出来的对象里取就行，多存一份只是多一份要同步的东西。唯一写入入口是 `PlanStore.save(_:)`：整份编码、整行覆盖，读的时候整份解，不存在半更新的中间态。

### 6.3 并发与删除

- 只有主线程（`@MainActor`）上下文，不建 `@ModelActor`。理由：单次写入最多几十行，主线程耗时在毫秒级；而 `@ModelActor` 内更新不触发视图刷新是 SwiftData 的已知问题，绕它需要额外机制。
- **表之间不建 `@Relationship`**，用 `sessionId` 外键式普通字段关联。避开关系链之后，删除语义变得简单：删计划不碰会话与日志，因为历史账本本来就不该随计划消失。`PlanStore.clear()` 只删自己那一行。
- 查询靠 `#Index` 与 `FetchDescriptor(predicate:)`，`SetLogStore.recentLogs()` 是唯一的「取最近」入口。

**「删计划会不会丢历史」这件事是设计选择，不是遗漏**：计划是模板，历史是既成事实。用户换一份计划，不该让上周练过的组数从记录页消失。

### 6.4 迁移

没有版本化的 `SchemaMigrationPlan`。理由是这张表结构极简（§6.1）：三张表里两张是 `payload: Data`，加字段只发生在 `SessionEntity` / `SetLogEntity` 上，且**一律加可选字段或给默认值**，SwiftData 的轻量迁移直接过。

已经走过的两次：

| 字段 | 表 | 迁移方式 |
|---|---|---|
| `SetLogEntity.catalogId` | 每组日志 | 可选，旧日志为 nil；跨版本统计动作时按 nil 跳过 |
| `SessionEntity.planDate` | 会话 | 可选，旧会话为 nil，读时回落到 `startedAt` 的日历日 |

两条都是**在旧库上覆盖安装实测过**的，不是推理。要加不可选字段时先想清楚旧数据填什么——如果想不出来，就说明它是可选字段。

计划 JSON 的 `schemaVersion` 与数据库版本分离：前者是契约版本（`PlanDecoder` 管），后者靠 SwiftData 自己的模型校验。

---
## 7. 计划 JSON 契约

契约文件：`docs/plan-schema.json`，JSON Schema 2020-12。

### 7.1 设计决策：结构在 Schema，取值在代码

`plan-schema.json` 刻意**只使用** `type / properties / required / additionalProperties / enum / items / $ref / $defs / description`。不使用 `minimum`、`maximum`、`pattern`、`format`、`oneOf`、`allOf`、`not`。

原因：AI 直连首选 `response_format: {"type": "json_schema", "json_schema": {"strict": true, ...}}`，而 Structured Outputs 只支持 JSON Schema 的一个子集，`minimum`/`pattern`/`format`/`oneOf` 均在子集之外，用了会被服务端拒绝或静默降级。把结构约束（必须有哪些字段、枚举值是什么）交给 Schema，把取值范围（组数 1–20、休息 0–600 秒、HH:mm 格式）交给 `PlanValidator` 的代码校验。

这样同一份 Schema 既能直接喂给 OpenAI 兼容服务做严格模式，也能作为本地解码器的唯一真相。

### 7.2 四条链路共用同一契约

```
            plan-schema.json（唯一契约）
              |         |          |          |
    AI 直连输出   用户粘贴 JSON  备份导出    SwiftData.planJSON
              \         |          |          /
                  PlanDecoder + PlanValidator + PlanNormalizer
                              |
                        ParsedPlanDraft
                              |
                        PlanReviewView（人工校正）
                              |
                        WorkoutPlan（正式）
```

### 7.3 反 null 规则

契约规定：所有字段必填；无内容填 `""`、`[]` 或 `0`；不出现 `null`。

理由：LLM 在"可空字段"上最容易出偏差——要么漏 key，要么给 `null`，要么给 `"null"` 字符串。统一成"必填 + 空值"后，解码器不需要处理三态，`strict` 模式下的失败率显著下降。

---

## 8. 计划获取链路

### 8.1 AI 直连：HTTP 契约

| 项 | 值 |
|---|---|
| 方法 | `POST` |
| 路径 | `{userBaseURL}/chat/completions`（用户填的 Base URL 末尾斜杠由 App 归一化，不重复拼 `/v1`） |
| 认证 | `Authorization: Bearer {key}` |
| 请求头 | `Content-Type: application/json` |
| 超时 | 连接 15s，总 60s |
| 请求体 | `{"model": "{userModel}", "messages": [{"role":"system","content": SYSPROMPT}, {"role":"user","content": userBrief}], "temperature": 0.2, "response_format": {...}}` |
| 不发送 | `max_tokens`（OpenAI 新模型已改用 `max_completion_tokens`，第三方兼容层对两者的支持不一致，留空让服务端决定）；`stream` |
| 成功响应 | `choices[0].message.content` 为符合 `plan-schema.json` 的 JSON 字符串 |

`response_format` 三级降级（同一个 `AIPlanClient` 内实现，顺序固定）：

| 级 | request 体 | 触发下一级的条件 |
|---|---|---|
| L1 | `{"type":"json_schema","json_schema":{"name":"dongke_plan","strict":true,"schema": <plan-schema.json>}}` | 返回 400 且错误信息含 `response_format` / `json_schema` / `not supported` |
| L2 | `{"type":"json_object"}` | 返回 400 且仍指向 response_format |
| L3 | 不带 `response_format`，靠 system prompt 硬要求输出 JSON | — |

三级都失败时不重试第四次，直接把原始响应正文（截断 500 字）与错误码交给 UI，同时允许用户切到粘贴路径。

### 8.2 错误分类

`AIPlanClient` 只抛 `AIClientError`，每种错误对应 UI 上一句可执行的中文提示：

| 错误 | 触发 | 给用户的话 |
|---|---|---|
| `.missingKey` | Keychain 无 key | 还没有配置 API Key，可以在设置里填，也可以改用粘贴导入 |
| `.invalidBaseURL` | Base URL 非 https 或不可解析 | 接口地址需要以 https:// 开头 |
| `.unauthorized` (401/403) | Key 无效或额度不足 | API Key 被拒绝，检查是否填错或额度用尽 |
| `.rateLimited` (429) | 限流 | 请求太频繁，10 秒后可重试 |
| `.serverError` (5xx) | 服务端故障 | 模型服务暂时不可用，稍后重试或改用粘贴导入 |
| `.timeout` | 超时 | 生成超过 60 秒，已中断。可以重试，或改用粘贴导入 |
| `.transport` | `URLError` | 网络不通，检查网络后重试 |
| `.emptyResponse` | content 为空 | 模型没有返回内容，重试一次 |
| `.invalidJSON` | 抠不出 JSON | 模型返回的不是 JSON，改用粘贴导入更稳 |
| `.schemaMismatch([ParseIssue])` | 解码失败 | 生成结果结构与要求不符，已列出问题项，可手动修正 |

重试策略：仅对 `.rateLimited`、`.serverError`、`.timeout` 各重试 1 次，退避 2 秒；`.unauthorized` 不重试（重试只会再撞一次）。

### 8.3 提示词模板（同一份，两处可用）

`AIPromptBuilder` 是纯函数：`makeMessages(profile: UserProfile, extraNote: String) -> [ChatMessage]`。同一段 system prompt 也用于"复制提示词"按钮——用户把它贴进 Claude / DeepSeek 网页版，拿到的结果再粘贴回 App 走 JSON 路径。这保证了"无 Key 也能用 AI"。

system prompt 骨架（要点，非全文）：

```
你是健身计划生成器。只输出一个 JSON 对象，不要输出解释、不要用 markdown 代码块包裹。

必须严格遵守以下结构（字段名、类型、枚举值一字不差）：
{在这里内联 plan-schema.json 的 $defs 展开版}

硬性要求：
1 所有字段必须出现；没有内容时字符串填空串，数组填 []，数值填 0；禁止 null。
2 days 固定 7 项，dayIndex 1 到 7 对应周一到周日，休息日也要有完整对象且 isRestDay 为 true、blocks 为 []。
3 daysPerWeek 必须等于 isRestDay 为 false 的天数。
4 catalogId 只能取以下值之一：squat, push_up, plank, lunge, glute_bridge, dumbbell_row,
  shoulder_press, jumping_jack, mountain_climber, dead_bug, high_knees, side_plank,
  calf_raise, bird_dog, superman, crunch, russian_twist, wall_sit；库外动作使用 custom_ 前缀。
5 单组目标三选一：type 为 reps 时 value 是次数，duration_sec 时是秒数，distance_m 时是米数。
6 notes 写动作要点，不超过 60 字，不要写营销文案。
7 居家场景，默认无器械；需要器械时必须使用用户已声明的器械。
```

user brief 由 `UserProfile` 拼装：身高体重年龄性别、目标、水平、可训练日与时长、器械、伤病限制、用户补充要求。

### 8.4 粘贴解析四级链路

```
输入文本
  │
  ├─ L1 严格 JSON：PlanJSONExtractor 抠出第一个完整 JSON 对象 → PlanDecoder(strict)
  │     成功 → 完成
  │
  ├─ L2 宽松 JSON：允许字段缺失/类型漂移，PlanNormalizer 补默认值、clamp 范围
  │     成功 → 完成，标记 3 条以内 warning
  │
  ├─ L3 自由文本启发式：FreeTextPlanParser
  │     能识别出至少 1 个动作 → 完成，标记 warning，进人工校正
  │
  └─ L4 全失败：生成空白草稿 + 用户原文，直接进人工校正界面
```

`PlanJSONExtractor` 要处理的真实脏数据（每条一个测试用例）：

- ```json 代码围栏包裹
- 前后夹带 "好的，这是你的计划：" 之类说明文字
- 结尾有 "希望这个计划对你有帮助！"
- 大括号内出现字符串里的大括号（必须做引号感知的括号配对，不能用 `firstIndex(of: "{")` + `lastIndex(of: "}")`）
- 尾随逗号
- 中文全角引号
- 单个对象外包了一层数组 `[{...}]`（解包取第一个元素）

`FreeTextPlanParser` 的启发式规则（每条一个测试用例）：

| 目标 | 识别模式 |
|---|---|
| 星期分区 | 周一/星期一/礼拜一/mon，以及 第1天/第一天 |
| 组数 | `3组`、`3 组`、`三组`、`3x`、`3×`、`3*` |
| 次数 | `12次`、`12 个`、`十二次`、`12-15次`（取上限）、`每组12` |
| 时长 | `30秒`、`30s`、`1分钟`（转 60） |
| 休息 | `休息60秒`、`组间休息 1 分钟`、`间歇90s`、`休 1min` |
| 每侧 | `每侧`、`单侧`、`左右各` |
| 循环/超级组 | `循环3轮`、`3轮`、`超级组`、`连做` |
| 热身放松 | `热身`、`放松`、`拉伸`、`cold down` |
| 备注 | `注意`、`要点`、`Tips` 之后的句子 |

中文数字转阿拉伯数字实现一张 0–99 的映射表（`一`…`九十九`），不用正则硬凑。

L3 的成功标准定得很低：能认出动作名与至少一组数字就返回草稿，剩下的字段留空并在 `PlanReviewView` 里用橙色标记，用户改完才能保存。宁可让用户改 5 个字段，也不要假装解析成功然后存进一份错计划。

### 8.5 校正界面是必经关口

除 L1 严格 JSON 且零 issue 外，所有路径都进 `PlanReviewView`。这不是可省略的一步：

- 计划是要照着练的，错一个组数就是错一次训练
- 让用户在保存前看一遍比事后"训练中才发现不对"便宜得多
- `ParseIssue` 逐条定位到字段路径（如 `days[2].blocks[0].items[1].restSec`），点一下跳到对应编辑控件

唯一例外：AI 直连返回 L1 零 issue 时，仍进预览页，但按钮直接是"保存并使用"，不强制编辑。

---

## 9. 通知与排程

### 9.1 生成规则

`WeeklyScheduleGenerator.makeSpecs(plan:settings:now:calendar:) -> [ReminderSpec]`

训练提醒：

| 场景 | 生成 | 数量上限 |
|---|---|---|
| 训练日提醒 | 每个 `isRestDay == false` 且 `scheduledTime != nil` 的日子一条，`leadMinutes` 提前 | ≤ 7 |
| 无 scheduledTime 的训练日 | 回退到 `ReminderSettings.overrideTimes` 首个时段 | ≤ 7（与上一条合计不超过训练日数） |
| 休息日 | 不生成训练提醒 | 0 |

本期只有训练日提醒一种，常驻待触发量 **≤ 7 条**。久坐提醒移到 P1（§9.6），排程方案已设计但不实现。

### 9.2 触发器选择

训练提醒用 `UNCalendarNotificationTrigger(dateMatching: DateComponents(hour:minute:weekday:), repeats: true)`。

- `weekday` 用 `Calendar.current` 的语义（1 = 周日），由 `Weekday.systemWeekday` 转换，禁止手写 `+1`/`-1`
- 重复触发器在系统侧只算 1 条待触发，7 条覆盖整周，不需要"补排未来 8 周"
- 已知行为：触发器按设备当前时区解释 `hour/minute`，用户跨时区后本地触发时间随本地时间走。对"每天 19:30 练"这种需求是想要的行为，不做特殊处理

`DateComponents` 的语义陷阱（P1 做久坐提醒时会踩，先记在这里）：`DateComponents(weekday: 2, hour: 9, minute: 0)` + `repeats: true` 等于**每周二 9:00 一次**，不是"每个工作日 9:00"。想表达"工作日 × 每天 N 个时刻"只能逐条展开，无法压缩。具体取舍见 §9.6。

### 9.3 通知标识符与预算治理

标识符前缀是唯一的所有权声明，`NotificationService` 只增删自己前缀下的通知，绝不调 `removeAllPendingNotificationRequests()`（会误删别处通知，也会打断正在进行的休息计时）。

| 前缀 | 用途 | 优先级 | 配额 |
|---|---|---|---|
| `dk.plan.{planId}.d{1-7}` | 训练日提醒 | 0 | 8 |
| `dk.rest.{sessionId}` | 休息结束 | 1 | 2 |
| `dk.test` | 设置页试发 | 2 | 1 |

（`dk.sed.*` 属 P1 久坐提醒，见 §9.6，本期不实现）

**常驻待触发量 = 训练日数 = ≤ 7 条**。配额上限 11 条，留 53 条余量，64 条上限在本期构不成风险。**配额不是"能用到这么多"，而是"超过就说明有 bug"**。

`NotificationService.reschedule(plan:settings:)` 固定四步：

1. 先清 `dk.plan.` 前缀下的旧条目（先清后排，避免旧计划残留与新计划叠加）；`settings.enabled == false` 时到此为止
2. `ReminderPlanBuilder.build(plan:settings:now:)` 为每个训练日生成一条规格——时刻取 `day.scheduledTime`，没有就用设置里的默认时间
3. 逐条 `add()`，触发器为 `UNCalendarNotificationTrigger(repeats: true)`
4. `refreshStatus()` 用 `pendingNotificationRequests()` 数出前缀匹配的条数（`scheduledCount`），交给 `ReminderHealth` 与期望值比较；少了就是 `.incomplete(missing:)`，今日页据此提示

第 4 步不只防 64 条裁剪。**权限被关、系统清理、卸载重装、用户手动关掉某一天**，都会让实际条数与期望不符，而 `add()` 一声不响。所以它是「提醒还在不在」的唯一可观测口径，`ReminderHealth` 与今日页的提示都建立在这个数上。

### 9.4 权限

请求时机定在**引导最后一屏之后**（时段选择之后），不是冷启动、也不是等到设置页。理由：用户刚做完提醒相关选择，此刻弹窗有上下文，授权率最高；且训练提醒默认开启，若不在引导里拿到权限，落地到首页就是"默认开但实际排不了"的欺骗性状态。

权限状态四态处理：

| 状态 | UI | 动作 |
|---|---|---|
| `notDetermined` | 引导第 5 步后弹系统请求 | 拒绝也继续，不阻塞引导 |
| `denied` | 今日页顶部一条可关闭提示 + 设置页"去系统设置" | 一键跳 `UIApplication.openSettingsURLString` |
| `authorized` | 设置页显示两组开关与时间 | 正常排程 |
| `provisional` | 按 `authorized` 处理，但提示"通知会安静送达" | 引导用户升级为正式授权 |

`denied` 时**不静默失败**：今日页必须仍能显示"今天该练什么"并可直接开始训练，通知只是加速器而非前提。这一条同时满足 PRD §9.3 可用性要求与 PRD 验收条目「通知权限被拒时给出引导文案与降级说明」。

前台收到通知时实现 `willPresent` 返回 `[.banner, .sound]`。默认前台不展示，这是"通知不生效"最常见的原因。

通知内容带 `categoryIdentifier`，注册三组 `UNNotificationAction`：

| Category | 动作 | 处理 |
|---|---|---|
| `workout` | 开始训练 / 稍后 30 分钟 | 深链到训练页 / 重排一条 `UNTimeIntervalNotificationTrigger` |
| `rest` | 结束休息 | 回到训练页并把状态机推到下一组 |

### 9.5 休息计时通知

训练中每次开始休息：

1. 存 `restEndAt = now + seconds`
2. 立刻 `add` 一条 `dk.rest.{sessionId}`，`UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)`
3. 用户加时 → 移除旧条、按新 `restEndAt` 重排
4. 用户跳过或休息结束回到前台 → 移除该条

这条通知是"锁屏后仍能知道休息结束"的唯一可靠手段，见 §10.3。

### 9.6 久坐提醒（P1，本期不实现）

**移出 MVP**，本期通知只有训练日提醒一种。以下结论保留，供 P1 接回时直接用，不重做调研。

⚠️ 本节出现的 `SedentaryResolver` / `SedentaryWindow` 是 P1 的设计草案，**代码里都不存在**；`ReminderSettings` 的时间窗字段也没有留位（§5 已删）。P1 真要接时按这一节重写，不要去找这些类型。

| 项 | 结论 |
|---|---|
| 频率 | **工作日每天固定 4 个时刻**（默认 10:30 / 14:30 / 16:30 / 20:00），可逐个关、可改时刻、整体可关。不做"每隔 N 分钟" |
| 为什么不做间隔式 | 间隔式要靠后台刷新重建通知，而 `BGAppRefreshTask` 的调用时机不受保证。提醒不响比提醒不准更糟，所以选可靠但粗粒度 |
| 排程 | 5 天 × 4 时刻 = 20 条 repeating（`weekday + hour + minute`），加训练 7 条 = 27 条常驻，余 37 条给休息计时，落在 64 条内 |
| 额度上限 | FROZEN-BASELINE 决策 8 已定**不做 48 小时滚动窗口**。P1 若接久坐，必须在"固定时刻 + repeating"这条路上重新核算额度，不能靠滚动窗口绕过 64 条上限 |
| 通知级别 | `.active`，不用 timeSensitive（理由见 §9.7 第 3 条） |
| 文案 | 不写"你已经坐了 2 小时"——不读 HealthKit 就不知道用户是否在动，只能写"起来动 1 分钟" |
| 稍后 | 30 分钟，当天累计 3 次后不再提醒；计数存 `ReminderSettingsRecord.snoozeCountToday` + `snoozeDate`，跨天归零 |
| 与训练重叠 | 落在训练时段内（`session.status == active`）的条目跳过，由 `SedentaryResolver` 纯函数判断 |

`SedentaryResolver.instances(window:slots:from:to:calendar:) -> [Date]` 在 P1 实现。纯函数，单测覆盖：窗内固定时刻、`weekdaysOnly` 跳过周末、跨零点窗口、区间跨月。

### 9.7 时效性通知（time-sensitive）

PRD R5 要求训练提醒穿透专注模式。技术上成立，但要分清两级：

| 级别 | 是否需要 Apple 审批 | 是否穿透专注模式 | 本项目用途 |
|---|---|---|---|
| `.active`（默认） | 否 | 否 | 本期未用；P1 久坐提醒用这一级 |
| `.timeSensitive` | 否。在 Xcode 里加 Time Sensitive Notifications capability 即得授权，不像 Critical 需要单独申请 | 是（当用户允许该 App 发时效性通知时） | 训练提醒、休息结束 |
| `.critical` | 是，需 Apple 单独批准 | 是，且绕过静音开关 | 不用。健身提醒不够格，申请会被拒 |

落地清单：

1. Xcode Target 的 Signing & Capabilities 里添加 **Time Sensitive Notifications**，生成 `com.apple.developer.usernotifications.time-sensitive` 授权项（写入 entitlements 文件）
2. 训练提醒与休息通知的 `UNMutableNotificationContent.interruptionLevel = .timeSensitive`
3. 本期只有训练与休息两类通知，都用 `.timeSensitive`。P1 的久坐提醒必须用 `.active`：HIG 要求时效性只用于"正在发生或一小时内发生"的事且不可滥用，每天数次久坐提醒用时效性属于滥用，会消耗用户信任，也可能被审核质疑
4. 用户可在 设置 → 通知 → 动刻 里单独关掉"时效性通知"，此时 `.timeSensitive` 降级为普通投递。App 内的通知自检页要能读出这一状态并说明"训练提醒可能被专注模式拦住"
5. 不使用 `.critical`，不申请 Critical Alerts entitlement

`interruptionLevel` 的实际效果依赖用户设置，不能承诺"一定穿透"。PRD 的措辞应为"采用时效性级别以尽可能穿透专注模式"，不是"保证穿透"。

---

## 10. 训练执行引擎

### 10.1 休息计时状态机（纯函数）

`RestTimerStateMachine` 不持有 `Timer`、不读 `Date()`。所有时间从事件里进来，所有副作用作为 `Effect` 出去。

```swift
enum RestState: Equatable {
    case idle
    case running(endAt: Date, totalSeconds: Int)
    case paused(remaining: TimeInterval, totalSeconds: Int)
    case finished(totalSeconds: Int)
}

enum RestEvent {
    case start(seconds: Int, now: Date)
    case tick(now: Date)
    case pause(now: Date)
    case resume(now: Date)
    case extend(seconds: Int, now: Date)
    case skip
    case cancel
}

enum RestEffect: Equatable {
    case scheduleNotification(endAt: Date)
    case cancelNotification
    case playHaptic
    case autoAdvanceToNextSet
}

static func reduce(_ state: RestState,
                   _ event: RestEvent,
                   _ effects: inout [RestEffect]) -> RestState
```

不变量（每条都要有测试）：

| # | 不变量 |
|---|---|
| 1 | `running` 态的剩余时间恒等于 `max(0, endAt - now)`，不做减法累加 |
| 2 | `tick` 时 `now >= endAt` 只产生一次 `finished` 与一次 `playHaptic`，重复 tick 不重复触发 |
| 3 | `pause` 时把剩余时间算出来存进 `paused`，不再依赖 `endAt` |
| 4 | `resume` 用 `now` 重建 `endAt`，暂停期间的时间不补扣 |
| 5 | `extend` 在 `running` 时移动 `endAt`；在 `paused` 时增加 `remaining`；在 `finished` 时按新时长重开 |
| 6 | `skip` / `cancel` 到 `idle` 并发出 `cancelNotification` |
| 7 | `idle` 收到 `tick` 无副作用 |
| 8 | 后台停留 10 分钟后回前台，一次 `tick` 直接到 `finished`（不得出现负数剩余或逐秒追赶） |

第 8 条是这个状态机的存在理由，也是绝大多数健身 App 的真实 bug 来源。

### 10.2 视图层职责

`WorkoutSession`（`@MainActor @Observable`，`Features/Workout/`）持有：

- `flow: WorkoutFlowModel`、`stepIndex: Int`
- `rest: RestState`
- `logs: [SetLog]`、`completedSets`
- 一个只在前台运行的 `Timer.publish(every: 0.25)`：每 tick 调一次状态机的 `tick`。0.25 秒粒度是为了让环形进度不跳格，同时避免 60Hz 定时器
- `scenePhase` 变化：进后台停定时器；回前台立即补一次 tick，让状态机自己处理时间跨越

它是训练页的唯一数据源，`AppShell` 只负责把它塞进 `fullScreenCover`。时长型动作（平板支撑、开合跳计时）用同一套状态机，把「休息」换成「动作计时」——不为它写第二套逻辑。

### 10.3 锁屏与后台的明确结论

iOS 在 App 进入后台后短时间内挂起进程，`Timer` 停止。这一点没有绕过办法（`beginBackgroundTask` 只给几分钟，且用于收尾而非持续计时）。所以：

- **不做**后台长时间计时，不申请后台音频模式伪装存活（会被审核质疑，且耗电）
- 唯一手段是 `endAt` 绝对时间 + 本地通知（§9.5）
- 回前台一律按 wall clock 重算，不补齐 tick

ActivityKit 实况通知（锁屏显示倒计时且不需要 App 运行）能显著改善体验，但需要额外 Target、额外权限配置与真机调试验证，本期列 P2，不进 MVP。

### 10.4 打卡与记录

会话状态在 `WorkoutSession`（`@MainActor @Observable`，`Features/Workout/`），逻辑分三个文件：主文件（状态与推进）、`+Flow`（序列推进）、`+State`（落盘与断点）。

- 每组落盘在完成的**那一刻**发生，不等训练结束。理由：健身房场景 App 可能被系统回收、来电可能打断、低电量模式可能挂起，等结束再批量写等于把用户一小时的工作押在一次写入上。
- 三态写入：`done`（按目标完成）/ `downgraded`（降阶完成，实际值低于目标或缩短时长）/ `skipped`（带 `SkipReason`）。三态分别累加，**不共用同一个计数**。
- **落盘时连归属一起写**：`SessionEntity.planDate` = 这一节兑现的那一天（`PlanCalendar` 算出），不是「点开始按钮的那天」。周日提前练下周一的课，`planDate` 是下周一。
- `undoLastSet` 只在会话未结束时允许，删除最后一条日志并回退计数。对已结束的会话调用必须抛错——这是「改今天的一组不得改昨天历史」的物理保证。
- `abandon` 保留已写入的日志，完成率照算。练了一半也是练了。
- 训练开始时把 `plannedSets` 写死。中途改计划不影响这次的分母；会话中「今天再加一组」也不改它，额外组以 `origin = .extra` 落一条独立日志，完成率与「练过没有」都只看计划内。
- 每条日志带 `origin`：`prescribed`（计划内）/ `extra`（当场加练）。旧 checkpoint 与旧库没有这个字段时按 `prescribed` 解码，不丢断点。
- 每次落盘后给一次轻量触感（`.light`），`reduceMotion` 或系统关闭触感时跳过。触感是「已记录」的唯一即时反馈。
- 落盘失败必须冒泡到 UI 显示「这一组没有保存成功」，不吞掉。

### 10.5 余力：每个动作的最后一组问一次

训练页在**每个动作收尾时**问一次「这组还剩几次力气」（1–5，不选也行），不是全天只问一次。静态动作问的是「还能撑几秒」，同一 1–5 刻度映射为 10 / 5 / 2 秒，阈值与次数共用（≤ 2 算有余力）。

| 决策 | 值 | 理由 |
|---|---|---|
| 采集点 | `WorkoutFlowModel.isLastSet(of:at:)` | 全天问一次的话，深蹲的余力和俯卧撑的余力落在同一格，对单个动作没有分辨力 |
| 存到哪 | `SetLog.rpe` | 与三态同一条记录，不另开表 |
| 用在哪 | 弱证据（§10.6）；另被 `DoseReport` 用来判有效组（`rpe ≥ 2` 或无自评） | 一条数据两个用途，两个用途的口径分别写在 §10.6 与 §11 |

代价是一节课多问四五次。若真机走查觉得烦，第一刀砍「收尾块不问」，保留主训练块——**不要反过来砍成「只问全天最后一组」**，那等于把这次改动撤销。

`recentLogs()` 按 `completedAt` **倒序**返回，所以取「某动作的最后一组」必须 `max(by: setIndex)`，用 `.last` 会拿到最早那组。这一条踩过一次，有测试守着。

### 10.6 剂量回路：`DoseAdjustment.propose`

**记录接回处方的唯一通道，是纯函数。**

```swift
public static func propose(_ context: DoseContext) -> PlanProposal?
public static func apply(_ proposal: PlanProposal, to plan: WorkoutPlan, now: Date) -> WorkoutPlan
```

`nil` 就是沉默。**没有提案不等于没数据，等于「还不够格说话」。**

优先级链（一次只出一张卡）：`保护（疼）` > `重建（停练太久）` > `换动作（没器械）` > `剂量（加量 / 减量 / 降量）`。

| 证据 | 门槛 | 动作 |
|---|---|---|
| 每组都 ≥ 目标 + 1 | 连续 2 次会话 | 加量，三级取最低：次数 +2 → 负重 ×耐受幅度 → 组数 +1 |
| 最后一组 `rpe ≤ 2`（还能做三次以上；静态还能撑 10 秒） | 连续 2 次会话 | 加量，**只动当前轴**：次数 +2，静态保持时间 +5 秒（上限 60 秒） |
| 同一动作标「太累」 | 连续 2 次会话 | 负重 ×0.9 或次数 −2，组数不动 |
| 同一动作标「没时间」，且那天动作 > 5 | 最近 3 次会话 | 砍掉那个动作 |
| 标「疼」 | 7 天内任意一次 | 该动作减 20%（负重 → 次数 → 组数） |
| 「没器械」跳过且有替代 | 最近一次会话 | 换成库内绕开器械的那一条 |
| `missedPlanDays ≥ 2` | — | 重建到八成效规模 |

八条硬约束：

1. **证据必须对着当前目标**：`log.plannedValue == item.target.value`，且只看 `origin == .prescribed` 的日志（额外组不构成计划证据），否则采纳后旧记录会立刻再判一次，来回摇
2. **一次提案只有一种 `field`**：加量取候选里最低那一档，不混着改
3. **强证据压过弱证据**：只要有任何动作拿到「每组都多做」，弱证据这一轮不出面——文案不能同时说两件事，且可核验的行为不该被感觉稀释
4. **拒绝被记住**：同指纹不再提、连拒三次整体安静、只有采纳清零（`ProposalMemo`，落 UserDefaults）
5. **降量绕过拒绝记忆**：疼和崩这件事，宁可重复一次
6. **七种沉默**：只说过一次 / 余力没选 / 余力记在中间组 / 最后一组是跳过 / 目标改过 / 次数或保持时间到顶 / 额外组上的余力
7. **覆盖度闸门**：某肌群可用动作 < 2 时不提案——换了也没得换
8. **重建不动 `revision`**：它不是新版本，是一次让步。其余三类采纳后 `revision + 1`

规则文件按「为什么变」拆四份（§4.2），不是按行数切的：`+Safety` 处理疼、`+Reduction` 处理换动作与减量、`+Progression` 处理加量与重建、主文件放入口与共用查表。加规则前先看目标文件是否接近 500 行门禁。

---

## 11. 完成率与统计

三个纯类型：`SessionLedger`（会话内分账）、`HistoryStats`（周与连续的账本口径）与 `DoseReport`（记录页读数）。**UI 不得自己算。**

会话内的完成 / 降阶 / 跳过 / 额外先由 `SessionLedger` 收口：它按 `SetLog.origin` 分账、按 `(sessionId, prescriptionId, setIndex, origin)` 去重，`SessionRecap`、`WorkoutSession`、持久化都从它取数。`HistoryStats` 与 `DoseReport` 只做跨会话聚合，不再各自数一遍日志。口径依据见 ADR-0006。

### 11.1 `HistoryStats`：周、连续、练过没有

输入统一是 `[SessionRecordSummary]`（date / plannedSets / completedSets / planDate），输出是数字。

| 指标 | 定义 | 边界处理 |
|---|---|---|
| 周进度 | 本周内 `planDate` 不同、且 `completedSets >= plannedSets` 的会话数 | 分母为 0 显示「—」，不显示 0%；按**计划日**归属，不按日历天 |
| 这一节练过没有 | 存在 `planDate` 与它同日、且全部组完成的会话 | 只做了一部分**不算**练过 |
| 连续天数 | 从今天往前，有全部组完成会话的日历天数连续计数 | 今天没练不算断链，从昨天起算 |
| 完成率 | 计划内完成组 / 计划组数，clamp 0…1 | 分子只数 `origin == .prescribed` 的 done + downgraded；`plannedSets == 0` 返回 `nil`，UI 显示「—」——休息日与失败日不能长得一样 |

后三条口径**故意不是同一件事**：

- **周进度按 `planDate`**：周日提前练下周一的课，记在下周一那一周，本周仍 0/3
- **连续天数按 `date`**（会话发生日）：周日练了就是练了，连续天数 +1
- **「练过」要求全部组完成**：与完成率的分子一致，否则一个 0/9 组的会话会让卡片写「已经练过」，而同屏周进度是 0/3

**额外组不进以上任何一条。** 跳过一个计划组、再当场加做两组，完成率仍是 11/12，`isCompleted` 仍是 false。额外组只进剂量（§11.2），因为它回答的是「练了多少」，不是「计划做完没有」。

`planDate` 为 nil 的旧数据回落到 `date` 的日历日——旧记录的表现与加这个字段之前完全一致。

周的口径固定为**周一到周日**（`calendar.firstWeekday = 2`），不跟随系统设置。计划是按周一到周日生成的，统计口径必须与计划口径一致，否则周与周之间会错位。

### 11.2 `DoseReport`：记录页那几屏数字

```swift
DoseReportBuilder.build(logs:now:weeks:calendar:) -> DoseReport
```

| 字段 | 含义 | 口径 |
|---|---|---|
| `effectiveSets` | 本周有效组 | `isEffective`：`status == .done && (rpe ?? 5) >= 2`。**没有自评按有效算**——记账要宽松，不能让忘点的人白练。**额外组也算**：它是真实做掉的刺激 |
| `muscles` | 九个肌群的组数与上周差值 | 按**主导肌群**记一次，不重复计（深蹲只算股四头，不算臀）；额外组同样计入 |
| `weeklySets` | 最近四周的有效组序列 | 趋势用 |
| `skips` | 五个 `SkipReason` 的降序切片 | 只数计划内；回答「为什么没做」，不回答「哪里弱」 |
| `completedSets` / `skippedSets` | 本周计划内完成 / 跳过的组数 | 与 `effectiveSets` 分开；额外组不进这两个数 |
| `extraSets` | 本周额外完成组数 | 只数 `origin == .extra` 且未跳过；单独显示，不混进完成率 |

**`effectiveSets` 与 `completedSets` 不是一个数**：前者回答「这周练够没有」，后者回答「这周做完多少」。合成一个数字会让「每组都力竭」和「每组都轻松」看起来一样。

**不做**：卡路里、训练量吨位、跨动作强度比较。这三件都要用到本 App 没有的数据（心率、负荷基线、动作难度系数），估出来只会让人做错误的横向比较。

---

## 12. 动作图示

**这一章不再维护规格。** 现行方案——素材血统、可测量的同风格基线、新增一个动作的流程、填色方式——全部写在 `docs/FIGURE-STYLE.md`，那是唯一维护点。

留在这里的只有两条架构约束：

| # | 约束 |
|---|---|
| 1 | 图示是**矢量 path 数据**（`DongKeCore/Figure/GeneratedFigureData.swift`，3MB，生成产物，不手改），不是图片资源，不进 `Assets.xcassets`，运行期不下载 |
| 2 | 渲染器只有一个（`ExerciseFigureView`），数据只有一份。新增动作只改生成器的映射表与测试里的数字，不改渲染代码 |

早期草案写的「自绘参数化骨架 12 关节」**已作废**：三代参数化自绘都收敛到同一个木偶感，判定不可行。不要在本文恢复那套规格——它描述的是一个没有采用的方案，留着只会误导下一个人。

[FROZEN-BASELINE 决策 6](../FROZEN-BASELINE.md) 记的就是这次改判：素材用 `bryllim/workout-guide`（源自 Everkinetic，CC BY-SA 4.0，必须保留署名），302 个动作、每个 3 帧。

---

## 13. 安全与隐私

### 13.1 密钥与传输

| 项 | 做法 | 禁止 |
|---|---|---|
| API Key 存储 | `KeychainService`，`kSecClassGenericPassword`，`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | 存 UserDefaults、存文件、存 SwiftData、写进 plist |
| Key 展示 | 只显示末 4 位（`sk-****abcd`），输入框 `isSecureTextEntry` | 明文回显完整 Key |
| Key 写入门禁 | 保存前先发一次最小请求验证（`GET {base}/models` 或 1 token 的 chat 请求），失败不保存 | 存了才发现填错 |
| 传输 | 强制 https。Base URL 非 https 直接拒绝并提示 | 允许 http；加 `NSAllowsArbitraryLoads` |
| 日志 | **生产代码零日志输出**（生产代码零注释、零调试残留是同一条纪律）。要加的第一条红线是脱敏：`Authorization` 一律替换为 `Bearer ***`，响应正文不整段落地 | `print` 请求头、`print` Key、把响应正文写日志 |
| 导出 / 备份 | **不做**。没有账号也没有云端；导出文件只在「换机」时显得有用，而那正是最需要格式稳定的场景。要做得先定格式版本与回导路径 | 假装支持导出却导不回来 |
| 数据出境 | 仅在用户主动点击"AI 生成"时把用户画像与要求发给用户自己的服务商，首次使用前明示 | 静默上报画像、上报计划原文、接入第三方分析 SDK |
| 本地数据 | 无账号无云同步，数据只在本机沙盒。App 内提供"清空全部数据" | 隐式上传、iCloud 同步 |

`Info.plist` 中不添加 `NSAllowsArbitraryLoads`。若用户 Base URL 是 `http://`，`AIPlanClient` 在发起请求前就抛 `.invalidBaseURL`，不依赖系统网络层兜底。

### 13.2 剪贴板

只用 `UIPasteControl`（iOS 16+ 的系统粘贴控件），不做 `UIPasteboard.general.string` 的隐式读取。`UIPasteControl` 由系统接管读取动作，因此既不触发"允许粘贴"的二次弹窗，也不存在后台读取的可能——这是既符合 PRD 隐私约束又有更好体验的唯一做法。

计划文本输入框的"从剪贴板粘贴"按钮绑定 `UIPasteControl`，不接受手写的读取逻辑。禁止在 `viewDidAppear`、`scenePhase` 变化、后台任务里读剪贴板。

### 13.3 离线优先是架构原则，不是优化项

PRD 把离线列在第一约束，架构上对应三条不可违反的规则：

1. **本地存储是唯一真源**。任何 UI 的数据来源都是 SwiftData（或由它派生的内存状态），不存在"先读远端再填本地"的路径。
2. **核心链路零远端依赖**。导入（粘贴通道）→ 排程 → 提醒（本地通知）→ 执行 → 打卡，全链路不发起任何网络请求。AI 直连是唯一网络出口，且它是**可选加速器**：关掉它，其余功能一个都不少。实现上 `AIPlanClient` 是整个 App 里唯一持有 `URLSession` 的类型，用 grep 可验证。
3. **写入失败必须可见**。磁盘写入失败时给用户明确提示并允许重试，不吞异常、不假装成功。PRD §9.3 的"不静默丢数据"是硬线。

### 13.4 埋点：本期没有

PRD §9.4 要求过埋点，实现时没有落地。**没有服务端时，本地埋点只有开发者自己看得到**——它既定位不了线上问题（拿不到用户的日志），也指导不了产品决策（样本只来自愿意导出的人）。留在代码里就是一层没人读的写盘。

要做先答两个问题：**给谁看、多久看一次。** 答不上来就别做——这与 UI 测试取消是同一条判据（§15.3）。

一条技术结论留档备查，它是可证伪的事实而不是判断：**纯本地通知拿不到「已投递」回执。** `UNNotificationServiceExtension` 只对远程推送生效，本地通知在系统投递时不回调 App。所以 `notification_delivered` / `notification_opened` 这对指标，在只有本地通知的架构里采不到前者；要投递级数据只能引入服务端推送，与「无后端」的范围直接冲突。

### 13.5 通知合规

不发送营销或推广内容（本期也没有运营位）。时效性级别只用于训练与休息两类用户主动设置的通知，见 §9.7。

---

## 14. 设计系统与图标锁定

### 14.1 图标：SF Symbols 6，唯一来源

锁定 **SF Symbols 6**（iOS 18 SDK 附带版本）。它是 Apple 的系统级矢量图标体系，与系统字体光学对齐，支持 9 种字重、3 种缩放、4 种渲染模式，自动适配深色模式与无障碍设置，零包体积、零依赖。

它同时满足 PRD §9.3"统一矢量图标库、不使用 emoji 作功能图标"的实质要求：SF Symbols 是矢量资源、有唯一的系统来源、全线稿与填充两套变体。PRD 里写的"统一 SVG 图标库"在 iOS 上应理解为"统一矢量图标库"，选型结论即 SF Symbols 6。

使用规则：

1. 全项目图标只通过 `DesignSystem/Icons.swift` 的 `enum Icons` 常量引用，禁止在视图里写字面量 `Image(systemName: "figure.walk")`（有门禁 grep）
2. 凡用到的 symbol 必须在 `Icons.swift` 里登记，一处登记 = 一处可审的清单
3. 尺寸只用三档：16 / 20 / 24 pt。其余尺寸需求先回来讨论，不允许随手写 18 或 22
4. 渲染模式默认 monochrome；需要强调时才用 hierarchical
5. 选 symbol 前在 SF Symbols App 里核对最低可用 iOS 版本，不得使用高于 18.0 才提供的 symbol
6. 不使用 emoji 充当图标
7. `AppIcon` 不使用 SF Symbols，也不使用与其混淆相似的图形（Apple 条款明确禁止将 SF Symbols 用于 App 图标、logo 或商标性用途）

### 14.2 图标与动作图示的边界

`Icons` 负责界面图标（导航、按钮、状态、空态）。`ExerciseFigureView` 负责动作线稿示意（§12）。

两者不混用：不拿 `figure.strengthtraining.*` 这类 SF Symbol 当动作教学图。它表达的是运动类别，不是动作形状，用户看它学不会深蹲。

### 14.3 颜色与排版：唯一来源是 design-tokens.json

唯一真相是 `docs/design-tokens.json`（28 个语义色，全部 light/dark 双值；另有 typography / spacing / size / radius / shadow / motion / component / a11y 共 431 个叶子节点）。

实现方式：**把 `design-tokens.json` 作为资源打进 App bundle，`Theme` 在启动时解码一次**，不在 Swift 里手写常量。

理由：28 色 × 明暗两套 = 56 个值。手写常量必然与设计稿漂移，而漂移是廉价但持续的返工。运行时解码一次（几十 KB）耗时在毫秒级，冷启动预算完全吃得下；换来的是"设计改色只改 JSON，零代码改动"。

约束：

- 语义色只通过 `Theme.color(.accent)` 这类访问器取用，禁止在视图里写 `Color(hex:)` 或 `.red`（有门禁 grep）
- `component` 段（15 项，如 `buttonPrimary` / `cardSelected`）映射为 `Theme` 的计算属性，视图里不重新拼装颜色组合
- 组件的间距、圆角、阴影一律取 token，不写魔法数字
- 深色模式不单独出配色，靠 token 的双值自动适配

主色已裁决：**深青绿 `#0E7C66`（深色 `#34B39A`）为唯一强调色，浅色为主、深色完整**（FROZEN-BASELINE 决策 11）。`docs/design-tokens.json` 的 `accent` / `chartPrimary` / `focusRing` 三个 token 同值，代码与文档不得另行指定颜色值。硬约束不变：不使用紫粉渐变，每屏强调色不超过 2 处。

### 14.4 字体：系统字体，零打包

| 角色 | 字族 | 来源 | 用途 |
|---|---|---|---|
| 标题 / 正文 / 中文 | SF Pro Display / SF Pro Text / PingFang SC | 系统 | 全部常规文本，走 Dynamic Type |
| 仪表数字 | 系统等宽（`.system(design: .monospaced)` + `.monospacedDigit()`） | 系统 | 仅休息倒计时与训练页主数字 |
| 等宽（非数字） | SF Mono | 系统 | 计划粘贴框、AI Key 输入 |

**不打包任何字体**（裁决：零打包）。倒计时需要的是等宽数字在秒数跳动时不横向抖动，系统等宽 + `.monospacedDigit()` 已经满足；88pt 的"仪表感"由字号、字重、等宽数字与环形进度等速消耗共同建立，不靠字族。为这点差别承担 40KB 包体、OFL 全文随仓、子集化流程与 Reserve Font Name 声明，不划算。

零打包的技术约束（缺一不可）：

1. `Info.plist` 的 `UIAppFonts` **保持为空**；仓库内不得出现 `.ttf` / `.otf` / `.ttc`，构建脚本不拷贝字体文件
2. 字体全部经 `Theme/Typography.swift` 单点封装：视图里不得写字体名、字族名或字号字面量，只调 `.timer` / `.workoutNumber` 这类语义入口
3. 等宽数字一律 `.monospacedDigit()`；等宽文本（计划粘贴框、AI Key 输入）用 `.system(design: .monospaced)`
4. 88pt 是全项目唯一自定字号；其余字号从系统文本样式派生，跟随 Dynamic Type
5. 无 OFL 授权文件、无子集化流程、无 Reserve Font Name 声明——这三项随「零打包」一并取消

约束三条：

1. 倒计时是全项目唯一自定字号（88pt，上限 96pt），**不跟随 Dynamic Type**：已 88pt 再放大没有意义
2. 不跟随缩放必须补无障碍：倒计时视图设 `accessibilityLabel("休息剩余")` + `accessibilityValue("1 分 20 秒")`，**每整 10 秒更新一次**。不取 5 秒：VoiceOver 播一句要 2–3 秒，5 秒粒度会让播报排队，用户听到的是滞后的时间
3. 其余全部文本走系统文本样式派生，动态字体自动生效

包体积核算：主二进制约 8–12MB（SwiftUI + SwiftData，无第三方，无字体文件）。加 `figure-specs.json` 约 40–60KB，总量在 12MB 以内。

字体政策已裁决，本节此前「打包 B612」的写法作废：**零打包**。依据是与零第三方依赖策略同源、省 40KB 包体、省 OFL 全文与子集化流程，`UIAppFonts` 保持为空。`SPEC.md` §4、本节、`UIUX.md` 与 `design-tokens.json` 的 `typography.fontPolicy` 四处现已一致，不得再另行指定字族。

### 14.5 文案口径

不写空话。通知文案、空状态、错误提示都要说清楚"发生了什么、下一步做什么"。示例：

- 空状态（无计划）：`还没有训练计划。粘贴一段计划文本，或者用 AI 生成一份。`
- 通知：标题 `今天练下肢`，正文 `深蹲 4 组、箭步蹲 3 组，预计 28 分钟`
- 错误：`接口地址需要以 https:// 开头`（而不是 `请求失败`）

### 14.6 已裁决事项

以下三条原为待裁决，现已定稿，不再讨论：

| # | 事项 | 裁决 |
|---|---|---|
| 1 | 主色 | 深青绿 `#0E7C66`（深色 `#34B39A`）；与 `design-tokens.json` 的 `accent` / `chartPrimary` / `focusRing` 同值 |
| 2 | 最低部署版本 | iOS 18.0。PRD §9.3 已于 v1.2 同步为 18.0，两侧一致 |
| 3 | 直连 AI 是否在 MVP | 在。BYOK + OpenAI 兼容单端点 + 非流式，约 3–4 人日 |


---

## 15. 测试策略

框架：Swift Testing（`@Test`、`#expect`、`#require`）用于全部逻辑测试。XCTest 仅用于 UI 自动化与性能基线。

原则：`DongKeCore` 必须 100% 可测且不依赖任何系统状态。**时间靠参数传（`now: Date`），不靠协议注入**——多一层抽象就多一处要读的间接；网络靠 `AITransport` 的值对象边界隔开，测试喂 `Data` 而不是发请求。

### 15.1 必测清单（纯逻辑，缺一不可）

| 模块 | 必测用例 |
|---|---|
| `PlanGenerator` | 单次动作数 ≤5、同主导肌群 ≤2、按星期轮转（同 focus 的两天不排同一批）、专项日不足 3 个本组动作就降级全身、全身日两组各 ≥2 且截断后不丢整条上肢、组数吸收预算、伤患与器械约束 |
| `DoseAdjustment` | 加量三级取最低、强证据要两次且**每组**都多做、余力只动当前轴（次数 +2 / 静态保持时间 +5 秒）、太累降 10%、没时间砍动作（动作数 >5 才砍）、疼减 20%、换动作需有替代、重建不动 `revision`、七种沉默、拒绝记忆与连拒三次静默、降量绕过拒绝 |
| `SessionLedger` | 额外组不进完成率分母；跳过一组 + 加做两组仍是 9/10；额外组不满足 `isCompleted`；重复日志按 `(sessionId, prescriptionId, setIndex, origin)` 去重；旧 checkpoint 缺 `origin` 或未知值都回落计划内 |
| `DoseReport` | 有效组口径（`rpe ≥ 2` 或无自评）、额外组算有效组但 `completedSets` 只数计划内、主导肌群只记一次不重复计、跳过原因降序、四周序列、空数据不崩 |
| `PlanJSONExtractor` | 代码围栏、前后说明文字、字符串内大括号、尾随逗号、全角引号、外层数组、空输入、超长输入（>64KB 直接拒绝） |
| `PlanDecoder` | 合法样本；缺字段；类型漂移（字符串 "3" 解成 Int）；未知枚举值；多余字段；`schemaVersion` 不认识 |
| `PlanValidator` | sets 越界（0、21）、restSec 越界（-1、601）、`scheduledTime` 格式错（"25:00"、"7:5"）、`days.count != 7`、`dayIndex` 重复、`daysPerWeek` 与实际训练日数不一致、`weekday` 与 `dayIndex` 不匹配 |
| `PlanNormalizer` | 缺 blocks 补空数组、重复 itemId 重编、sets clamp 到 1...20、restSec clamp 到 0...600、按 dayIndex 排序 |
| `FreeTextPlanParser` | 中文数字（三组十二次）、`3x12`、`3×12`、`12-15次`、`30秒`、`1分钟`、`每侧`、`循环3轮`、`超级组`、`热身`、无数字只有动作名、完全无关文本（返回空草稿而不是崩溃） |
| `RestTimerStateMachine` | §10.1 的 8 条不变量逐个覆盖；额外覆盖：tick 早于 endAt、正好等于 endAt、pause 后 tick 无效、extend 三段行为、skip 在 idle 态 |
| `WorkoutSession` + `WorkoutFlowModel` | 普通三动作日、循环块 3 轮、超级组 0 休息、休息日为 0 步、`plannedSets` 计数、每个动作「最后一组」的判定、undo 连续 3 次、undo 到 0 后不再减、abandon 保留已完成、finish 幂等 |
| `WeeklyScheduleGenerator` | 有时间的训练日、无时间的回退、休息日不生成训练提醒、`leadMinutes` 跨零点（00:05 提前 30 分钟） |
| `ReminderPlanBuilder` + `ReminderTrigger` + `RestNotificationBuilder` | 训练日 0 / 3 / 7 条时的生成数量；超出配额时截断；前缀不匹配的条目不被删除；`dk.plan.` 回读复核缺项能被检出；时区与跨年触发时刻 |
| `HistoryStats` | `plannedSets == 0` 返回 nil；周进度按 `planDate` 归属；`isDone` 要求全部组完成；上周记录不算成下周；旧数据（`planDate` 为 nil）回落到会话日；连续天数在「今天未练」时的判定；周口径固定周一起 |
| `PlanCalendar` | 训练日=今天；休息日取下一个训练日（可跨周）；计划无训练日返回 nil；`dayIndex` 指向休息日返回 nil；深链按锚点归属；提前练归属到目标那一周；跨年边界 |
| `SetLogStore` 写入权限 | 对已结束会话调 undo 必须抛错；已结束会话的日志不可被修改；一次「完成一组」的 save 是原子的（日志与计数同进同退） |
| `FigurePlayback` | elapsed 为 0、整周期、相位取模（1.2 周期 → 0.2）、负数 clamp、帧数为 1 与 3 |
| `ExerciseFigure` 数据门禁 | 每个动作恰 3 帧、`catalogId` 覆盖动作库全部条目、`_generic` 占位存在、path 数据非空、view/props 枚举合法 |
| `Icons` 清单 | 白名单内每个 symbol 名称在 iOS 18.0 可用（编译期 `Image(systemName:)` 存在性靠真机验证，清单里标注可用版本） |
| `Weekday.systemWeekday` | monday→2、sunday→1、saturday→7（**这一条最容易写反，必须有测试**） |
| `AIPromptBuilder` | 提示词包含全部 catalogId 白名单；包含用户伤病限制；模板中的 JSON 部分可被 `PlanJSONExtractor` 反解出结构说明 |

### 15.2 怎么把系统依赖挡在测试外面

| 依赖 | 做法 |
|---|---|
| 当前时间 | **参数注入，不是 Clock 协议**：所有纯函数签名带 `now: Date = Date()`，测试传固定值。少一层抽象，读代码时也能一眼看出哪里用了时间 |
| 网络 | `AITransport` 是值对象（构造 request、解析 response），测试直接喂 `Data` 或构造错误，不发请求 |
| AI 生成 | `AIPlanGenerating` 协议在 `DongKeCore/Ports/`，实现在 `Services/AIPlanClient`；单测不碰实现 |
| 通知 | **不 mock**。`UNUserNotificationCenter` 单测里一律不碰，真实行为靠真机走查 |
| SwiftData | 单测完全不碰。`DongKeCoreTests` 只链 `DongKeCore`，起不了库也不需要起 |
| Keychain | 没有单测。`KeychainService` 只有三条路径（存 / 读 / 删一个 key），真机走查覆盖 |

**「不测」是判断，不是遗漏**：后三行要么不可伪造（通知由系统投递），要么测起来要先搭一个世界（SwiftData / Keychain），而它们承载的逻辑几乎为零。要恢复，先回答「它能抓到什么上面这些抓不到的」。

### 15.3 端上 UI 验证

**不做 XCTest UI 测试**（2026-10-25 定，目标与目录一并删除）。理由不是「不重要」，是成本收益不成立：一轮约 6 分钟，抓到的是布局与命中区回归，而这类问题的反馈速度必须快到「改完立刻知道」才有用——6 分钟的循环给不了这个。

三条主链路仍是**每次发布前的人工走查项**：

1. 引导问卷走完 → 保存 → 进今日页
2. 粘贴合法 JSON → 预览 → 保存 → 今日页出现该计划
3. 粘贴非法文本 → 预览页出现橙色 issue → 手动改正 → 保存成功

替补手段是把可自动判定的部分往上提：命中区与文案的下界写进单测（`#expect(target.value == ...)` 之类），布局本身靠真机走查。`Shared/A11yIdentifiers.swift` 保留——视图仍用它设 `accessibilityIdentifier`，那是 VoiceOver 的词汇，不是 UI 测试的私产。

性能不设自动化门槛，iPhone SE 3 仍是验收机型，人工观察掉帧与卡顿。

---

## 16. 风险清单

按"出问题后用户能否自己绕过去"排序，越靠前越严重。

| # | 风险 | 后果 | 对策 | 兜底 |
|---|---|---|---|---|
| 1 | 通知权限被拒 | 核心提醒能力失效，产品价值归零 | 在提醒设置页内请求而非冷启动；先解释再弹窗；`denied` 时给一键跳系统设置 | App 内今日页显示"今天该练什么"，不依赖通知也能用 |
| 2 | 后台与锁屏计时 | 休息倒计时停走，用户以为休息结束时间错乱 | 不做后台计时；`restEndAt` 绝对时间 + 本地通知；回前台按 wall clock 重算；`isIdleTimerDisabled` 在训练中置 true | 状态机不变量 8 的单测；真机锁屏 90 秒验证 |
| 3 | AI Key 泄露或误用 | 用户付费额度被盗刷，信任崩塌 | Keychain 存储；强制 https；日志脱敏；导出剥离 Key | 设置页可一键清除 Key；Key 永不回显完整值 |
| 4 | 解析失败率偏高 | 用户导入 3 次都失败，直接卸载 | 四级降级链路；`ParseIssue` 精确定位；校正界面永远可完成保存 | 提供示例 JSON 一键填入，让用户先看到成功长什么样 |
| 5 | 骨架渲染掉帧与数据错误 | 训练页卡顿，或某动作姿态画错（骨长跳变、越界被缩到看不清） | 纯 `Path` 绘制，无线稿解码；`TimelineView` 限 30fps；同屏只 1 个播放；列表内静态首帧；帧索引与 autofit 均为纯函数并有单测 | iPhone SE 3 为性能验收机型；§12.5 七项门禁在 CI 跑，缺项或骨长超容差即红 |
| 6 | SwiftData 关系链缺陷 | 深层 to-many 链上删不干净，历史账本出现孤儿 | 计划存 JSON 文档列；表之间不建 `@Relationship`；删计划不碰会话与日志 | 无自动化——「删计划不动历史」是设计选择，不需要断言 |
| 7 | 时区与星期换算 | 提醒错一天，最伤信任的 bug | 自有序 `Weekday` + `systemWeekday` 转换函数；对应单测 | 真机改时区手工验证一次 |
| 8 | 粘贴内容超长或恶意 | 内存暴涨、解析卡死主线程 | 输入硬上限 64KB，超出即拒绝并提示；解析在后台 `Task` 跑 | 解析失败不阻塞 UI，用户可返回重来 |
| 9 | 通知文案与计划脱节 | 改了计划但通知没更新 | 四个重建时机写死；标识符前缀所有权 | 设置页提供"重排提醒"手工按钮 |

---

## 17. 决策记录

| 编号 | 决策 | 选择 | 理由 | 放弃的方案 |
|---|---|---|---|---|
| D-01 | UI 框架 | SwiftUI | 与 SwiftData / UserNotifications / Charts 同源，零依赖，代码量最小 | UIKit、Flutter、React Native |
| D-02 | 最低 iOS 版本 | 18.0 | 覆盖 93% 在用 iPhone；可获得 SwiftData 的 `#Index`/`#Unique` 与成熟度改进 | 17.0（省 3%，换来 SwiftData 初版缺陷）；26.0（少 14%） |
| D-03 | 持久化 | SwiftData | 声明式绑定，`#Index` 满足全部查询 | Core Data（样板多）、GRDB（违零依赖）、JSON 文件（无索引） |
| D-04 | 计划存储形态 | JSON 文档列 + 冗余展示列 | 契约已在手；计划是文档不是事实表；规避深关系链缺陷 | 6 张关系表 |
| D-05 | 打卡记录存储形态 | SwiftData 关系表 | 需要按时间与动作聚合查询，索引有价值 | 与计划同存 JSON |
| D-06 | 动作库 | 只读 bundle JSON，内存索引，锁定 18 条 | 18 条常量与计划契约白名单一致，进库只增加失败面 | 播种进 SwiftData |
| D-07 | 通知触发方式 | `UNCalendarNotificationTrigger` + `repeats: true` | 单计划 ≤7 条，永不相撞 64 上限；重复触发器只占 1 条 | 逐条排 8 周 |
| D-08 | 后台计时 | 不做。绝对时间 + 本地通知 | iOS 不提供持续后台计时，任何绕法都会在审核或耗电上付代价 | 后台音频模式伪装、`beginBackgroundTask` 长时间占位 |
| D-09 | 计划解析 | 严格 JSON 主路径 + 启发式兜底 + 强制人工校正 | 召回率与可控性的平衡点 | 只做 AI、只做文本解析 |
| D-10 | AI 调用 | `URLSession` 直连 + `response_format` 三级降级 + 非流式 | 兼容性覆盖最大化，实现量最小 | 官方 SDK、流式 SSE |
| D-11 | AI 输出约束 | Schema 只表达结构，取值范围由代码校验 | OpenAI strict 子集不支持 `minimum`/`pattern`，写进去会失效 | 在 Schema 里写全约束 |
| D-12 | 空值表示 | 必填 + `""`/`[]`/`0`，禁 null | LLM 在可空字段上偏差最大，三态转两态显著降失败率 | 允许 null |
| D-13 | 动作图（v1.1 曾改素材，v1.3 按 FROZEN 决策 6 恢复） | 参数化骨架 + 关键帧插值 + SwiftUI Shape，12 关节 | 零授权义务、动作数据完全可控；素材方案的 CC BY-SA 与商店 DRM 相容性工程无法拍板 | 第三方线稿素材、Lottie、逐动作手写 Path、视频 |
| D-14 | 图标 | 锁定 SF Symbols，经 `Icons.swift` 单一入口 | 系统级矢量、自适应外观、零体积 | 自建 SVG 集（维护成本高且与系统字体不对齐） |
| D-15 | 依赖策略 | 零第三方 | 减少审核风险、体积、版本腐化 | 按需引入 |
| D-16 | 并发模型 | 仅主线程 `ModelContext`，不引入 `@ModelActor` | 写入量小；`@ModelActor` 内更新不触发视图刷新是已知缺陷 | `@ModelActor` 后台写 |
| D-17 | 周统计口径 | 固定周一到周日 | 必须与计划生成口径一致，否则跨周错位 | 跟随系统 `firstWeekday` |
| D-18 | 代码注释 | 生产代码 0 注释 | 注释会与实现失同步；解释力放到本文与测试名 | 允许注释 |
| D-19 | 离线边界 | 全链路零远端依赖，`AIPlanClient` 是唯一持有 `URLSession` 的类型 | 离线是 PRD 第一约束；单点出口可用 grep 验证 | 多出口、按需联网 |
| D-20 | 动作图示素材 | ~~不使用第三方素材~~ **已撤销**（FROZEN-BASELINE 决策 6 改回 `bryllim/workout-guide` 线稿，署名 CC BY-SA 4.0） | 原理由：规避 share-alike 与商店 DRM 的相容性争议。改判理由：三代参数化自绘都收敛到同一个木偶感，达不到可用质量；素材 + 保留署名没有实质风险 | 自绘参数化骨架（已作废，见 §12） |
| D-21 | 骨架数据覆盖范围 | 只做 18 个 catalogId + `_generic`，不扩到 60/302 | 与计划契约白名单严格相等；扩动作只是加 JSON 不动代码，但每个动作都要手标，留到 P1 | 60 动作全量、302 动作全量 |
| D-22 | 久坐提醒 | **移出 MVP，列 P1**。P1 形态为工作日每天 4 个固定时刻（5×4=20 条 repeating） | 间隔式要靠后台刷新重建通知，而 `BGAppRefreshTask` 时机不受保证；提醒不响比提醒不准更糟 | 间隔式提醒、本期硬塞进 MVP |
| D-23 | 通知预算 | 本期常驻 ≤7 条（仅训练日提醒），配额上限 11 条 | 64 条上限在本期不构成约束；复核机制仍保留，因 P1 接久坐后它会立刻变成必需 | 预留 27 条常驻、无复核机制 |
| D-24 | 时效性通知 | 训练与休息用 `.timeSensitive`；不申请 Critical | timeSensitive 只需 Xcode capability 无需 Apple 审批；Critical 需 Apple 单独批准且健身场景不够格 | 全部 timeSensitive、申请 Critical |
| D-25 | 通知权限时机 | 引导最后一屏之后请求 | 用户刚做完时段选择，上下文最强；训练提醒默认开，早拿权限才不会出现"默认开但排不了" | 冷启动请求、等到设置页 |
| D-26 | 打卡三态 | `done` / `downgraded` / `skipped` + 跳过原因枚举 | 布尔表达不了"降阶完成"；完成率与降阶率要分开算，否则 100% 会掩盖事实 | `isSkipped: Bool` |
| D-27 | 跳过并顺延（P1） | **本期不做**（FROZEN §2）。本期排期只有 weekday 匹配，见 §5.4 | 顺延会让"今天该练什么"依赖历史状态推导，MVP 先保证规则可解释 | 本期实现 `ScheduleAdjustment` + 链式顺延 |
| D-28 | 预留同步字段 | ~~加 `ownerId` / `updatedAt`~~ **已撤销**：实现时一个都没加 | 原理由：加字段成本近零，省一次迁移。改判理由：**没人读的字段只会腐烂**，而 P1 真要接同步时按那一版 schema 重写更省事 | 现在就设计同步状态机 |
| D-29 | 剪贴板 | 只用 `UIPasteControl`，不隐式读 `UIPasteboard` | 系统接管读取，无二次弹窗、无后台读取可能，同时满足隐私与体验 | 手写 pasteboard 读取 |
| D-30 | 埋点 | 只落本地 JSONL，不上传；不采 `notification_delivered` | 本期无后端；本地通知拿不到投递回执，这是平台限制不是偷懒 | 假埋点、接第三方 SDK |
| D-31 | 设计 token 来源 | 运行时解码 bundle 内 `design-tokens.json`，不手写 Swift 常量 | 56 个色值手写必然漂移；解码一次毫秒级 | 手抄常量、构建脚本生成 |

---

## 18. 明确不做（out-of-scope）

本期不做，不是为了省事，是因为做了会把 MVP 从 4 周拖成 3 个月。

| 不做 | 说明 |
|---|---|
| 账号、登录、注册 | 无自建后端，数据只在本机 |
| 云同步、iCloud 同步、多设备 | 同上 |
| 自建后端、服务端解析计划 | 同上 |
| 饮食、蛋白质、卡路里记录 | P1，本期不做 |
| 视频动作教学 | P2，本期只有矢量图 + 文本要点 |
| Live Activity 实况通知（锁屏倒计时） | P2。需要额外 Widget Target 与真机验证 |
| AlarmKit（iOS 26 独占的强提醒闹钟） | P2。会把最低版本抬到 26，代价过大 |
| Apple Watch 伴生 App、HealthKit 写入 | P2 |
| 社交、排行、分享海报 | 不做 |
| 订阅、内购、支付 | 不做 |
| 第三方分析 SDK、崩溃上报 SDK | 不做。统一走 OSLog，本地可查 |
| 埋点上传通道 | 不做。本期无服务端，只落本地 JSONL，见 §13.4 |
| `notification_delivered` 投递回执 | 做不到。纯本地通知无投递回调，只能采 scheduled 与 opened |
| 同步状态与"待同步"提示 | 不做。本期无同步，UI 不出现同步字样 |
| 读取"运动与健身"步数权限 | 不做。久坐提醒按固定时刻触发，这是有意减少权限摩擦 |
| 久坐提醒（时间窗 + 固定时刻 + 稍后 30 分钟） | 移到 P1。设计结论保留在 §9.6，本期不实现、不做通知 |
| 跳过并顺延（`ScheduleAdjustment` + 链式顺延） | 移到 P1。本期排期只有 weekday 匹配，见 §5.4 |
| 计划内动作的编辑与替换 | 不做。校正界面只改字段，不提供"换成另一个动作"的推荐 |
| 用户自定义动作的编辑与入库 | 不做。`custom_` 前缀动作只存在于计划 JSON 里，不进动作库 |
| AI 生成饮食计划、动作替代推荐 | 不做 |
| 计划模板市场、内置计划库 | 不做。用户自带或 AI 生成 |
| 深色模式手工配色方案 | 不做单独配色。语义 token 自动适配系统外观 |
| iPad 专属布局、横屏优化 | 不做。手机竖屏为唯一目标 |

---

## 19. 端到端验证步骤

每条都要在真机上跑，模拟器不能验证通知与锁屏。

### 19.1 主成功流（必须全绿才算交付）

前置：卸载重装，确保是冷启动首次状态。

1. 冷启动 → 出现引导问卷，**不弹通知权限**。走完 5 屏 10 个字段（性别年龄 / 身高体重 / 目标水平 / 可训练日 + 时长 / 常练时刻 + 器械 + 伤病），每屏有预填默认值，直通 ≤60 秒
2. 进入计划导入页，点"用 AI 生成"，填入测试用 Base URL 与 Key（或点"复制提示词"，贴到外部模型，把结果粘回来）
3. 生成成功 → 进入计划预览页 → **零 issue** → 点"保存并使用"
4. 回到今日页：如果今天是周一/三/五，显示当天训练摘要（动作数、总组数、预计时长）；否则显示下一个训练日
5. 引导第 5 屏选完提醒时间后立即弹权限请求 → 允许；再进提醒设置页确认时间 19:30
6. 用 `xcrun simctl` 或真机把系统时间调到今天 19:29，等待通知在 19:30（或提前 `leadMinutes`）准时出现，标题为该日主题，正文含动作数与时长
7. 点通知进入 App，落到训练页
8. 完成第 1 组 → 点完成 → 出现休息倒计时，环形进度在走
9. **立刻锁屏，等待 90 秒**（若动作休息为 60 秒），解锁
10. 断言：倒计时显示已结束（不是剩余 30 秒），且锁屏期间收到"休息结束"通知
11. 继续完成全部组 → 结束训练 → 汇总页显示完成率 100%
12. 进入历史页：今天一条记录，完成率 100%，周完成率按 1/3 显示，图表有一个柱

### 19.2 关键错误流（必须全绿）

1. 在计划导入页粘贴 `今天练一下胸吧，随便练练` → 保存被拒绝，进入校正页，issue 提示"未识别到任何动作"，页面提供"填入示例"按钮
2. 粘贴去掉 `restSec` 的 JSON → L2 宽松解析成功，预览页显示 1 条 warning（"缺少组间休息，已按 60 秒补齐"），可编辑后保存
3. 把 Base URL 填成 `http://api.example.com` → 保存时即提示"接口地址需要以 https:// 开头"，不发请求
4. 把 Key 填成 `sk-wrong` → 验证请求返回 401 → 提示"API Key 被拒绝"，**Key 未被保存**
5. 在系统设置里关闭通知权限 → 回到 App 提醒设置页显示"已关闭，去系统设置打开"，并有跳转按钮
6. 训练中把 App 从后台杀掉再重开 → 今日页显示"上次训练未完成"，可继续或放弃；已完成组数不丢

### 19.3 断网、崩溃与通知（PRD 硬指标）

1. **飞行模式全流程**：打开飞行模式 → 冷启动 → 粘贴导入一份计划 → 排程 → 等到提醒时刻收到通知 → 开始训练 → 完成 3 组 → 结束 → 历史页出现记录。全程不得出现任何网络错误提示或重试按钮
2. **崩溃恢复**：训练到第 2 个动作第 2 组时，从多任务上划杀掉 App → 重新打开 → 今日页显示"上次训练未完成"，点继续 → 回到第 2 个动作第 2 组，已完成组数与完成率与杀进程前完全一致
3. **低电量模式**：开启低电量模式重复第 2 条，结论相同
4. **通知数量**：导入一份每周 3 练的计划 → `pendingNotificationRequests()` 中 `dk.plan.` 条目数必须等于 3，总数不超过 11，且不存在其他前缀的残留
5. **时效性**：开启"勿扰/专注模式"，训练提醒仍能横幅展示；在 设置 → 通知 → 动刻 里关闭"时效性通知"后再测，此时按普通级别投递（专注模式下被折叠），App 内通知自检页应反映出这一变化

### 19.4 性能与外观

1. iPhone SE（第 3 代）：训练页 30 秒，Instruments Animation Hitches 无掉帧记录
2. 深色模式切换，全部页面无硬编码颜色残留（对比度不低于 4.5:1）
3. 系统字号调到最大，训练页与预览页无截断（必要时换行而非缩字号）
4. 开启"减弱动态效果"，动作图变静态，倒计时数字仍在更新

---

## 20. 开发交付 checklist

**这节是开工前用的，已经不适用。** 项目已交付并进入迭代；保留原条款只会让人以为还要按「空实现 → 冻结签名 → 空壳测试」的顺序再来一次。要考古见 git 历史。

现在动手一个改动，只有三条前置：

- [ ] 读过 `FROZEN-BASELINE.md` 与 `SPEC.md`，确认没有撞上冻结决策
- [ ] 想清楚它落在 `DongKeCore` 还是 `DongKe`（§4.1）。纯逻辑写进视图，就没法被单测钉住
- [ ] 想清楚它由哪条测试守着。想不出来，说明要么不需要这个改动，要么还没想清

改完之后必跑 §4.3 的门禁 grep，以及 `DongKeCoreTests` 全量单测（§15.3）。
