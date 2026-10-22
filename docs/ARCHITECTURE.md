# 动刻 iOS 架构设计

版本：v1.3
状态：Phase 1 冻结，可进入实现
适用范围：居家减脂运动提醒助手 iOS MVP（iPhone）
配套契约：`docs/plan-schema.json`（计划数据唯一契约）
生效顺序：`docs/FROZEN-BASELINE.md` + `docs/SPEC.md` > 本文 > `docs/PRD.md` / `docs/UIUX.md` / `docs/design-tokens.json`。冲突时以 FROZEN-BASELINE 与 SPEC 为准。
关联文档：`docs/PRD.md`（需求）、`docs/UIUX.md`（页面与视觉）、`docs/design-tokens.json`（设计 token）

修订记录：

- v1.0 首版：技术选型、分层、数据模型、计划契约、通知与训练引擎、测试策略
- v1.1 吸收 PRD 与 UIUX 的硬约束后修订：动作图示从"自绘骨架"改为"开源线稿素材"（D-20）；新增久坐提醒链路与时效性通知（§9.7）；打卡改为三态（D-26）；新增跳过并顺延的排期解析（§5.4）；新增动作线稿授权履行义务（§12.3，v1.3 已撤销）；新增埋点只落本地的说明与 `notification_delivered` 不可得的结论（§13.4）；通知权限请求时机改到引导最后一屏（D-25）
- v1.2 定稿收敛：动作库锁定 18 个 catalogId（与 `plan-schema.json` 白名单一致）；素材入包 18 动作 × 3 帧 = 54 张，新增 §12.5 文件映射表与导入流程（v1.3 已撤销）；久坐提醒移出 MVP 列 P1（§9.6），通知常驻量回到 ≤7 条、预算按此重算（§9.3）；主色裁决为深青绿 `#0E7C66`（§14.3、§14.6）；取消打包字体，改系统等宽（§14.4）；最低版本 iOS 18.0 与直连 AI 进 MVP 均确认
- v1.3 按 `FROZEN-BASELINE.md` 回同步：动作图示恢复为**自绘参数化骨架 12 关节**（决策 6，撤销 D-20 的第三方素材）、主色确认**深青绿 `#0E7C66` / `#34B39A`**（决策 11）、**跳过并顺延移出 MVP 列 P1**（§2）、打包 B612 Mono Bold（SPEC §4）、久坐额度不再提 48 小时滚动窗口（决策 8）；§12 全章重写，§5.4 退化为 weekday 匹配

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
| 字体 | 系统字体（SF Pro / PingFang SC）+ 打包 B612 Mono Bold（OFL，子集 <40KB），仅倒计时与训练主数字 | 见 §14.4 |
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

```
        App（装配层，唯一可以 import 一切的地方）
              |
   +----------+-----------+-------------+
   |          |           |             |
Features   DesignSystem  Services      Data
(UI+VM)    (纯展示)      (系统能力封装)  (SwiftData + Repository 实现)
   |          |           |             |
   +----------+-----------+-------------+
              |
           Domain（纯 Swift：模型、解析、排程、状态机、端口协议）
```

硬规则：

| # | 规则 |
|---|---|
| 1 | `Domain` 只 import Foundation。禁止 import SwiftUI / SwiftData / UserNotifications |
| 2 | `Data` import Foundation + SwiftData + Domain。禁止 import SwiftUI |
| 3 | `Services` import Foundation + 系统框架 + Domain。禁止 import SwiftUI、禁止 import SwiftData |
| 4 | `DesignSystem` import SwiftUI + Domain（只读模型用于展示） |
| 5 | `Features` import SwiftUI + Domain + DesignSystem + Services。**禁止直接 import SwiftData** |
| 6 | `App` 是唯一装配点，负责创建 `ModelContainer`、Repository 实例、注入到 View 树 |
| 7 | 依赖只能向下。Features 与 Services 之间不互相 import；两者通过 Domain 中定义的端口协议解耦 |
| 8 | 端口协议（Repository / Service 的抽象）放在 `Domain/Ports/`，实现放在 `Data/` 与 `Services/` |

第 5 条是这套分层的关键：Feature 只认 `Domain/Ports` 里的协议，于是 ViewModel 测试可以塞假实现，不需要起 SwiftData。

### 4.2 目录结构（点名到文件）

```
DongKe/
├── App/
│   ├── DongKeApp.swift                 # @main，只做 Scene 装配，业务为零
│   ├── AppContainer.swift              # 依赖容器：构造 ModelContainer、Repository、Service
│   ├── AppDelegate.swift               # 通知代理 + isIdleTimerDisabled 控制
│   └── RootView.swift                  # 引导完成与否的分流，不写业务逻辑
│
├── Domain/
│   ├── Models/
│   │   ├── Weekday.swift               # 自有序枚举 monday=1...sunday=7
│   │   ├── TimeOfDay.swift             # hour/minute，Codable，非 Date
│   │   ├── UserProfile.swift
│   │   ├── WorkoutPlan.swift           # 聚合根
│   │   ├── PlanMeta.swift
│   │   ├── PlanDay.swift
│   │   ├── ExerciseBlock.swift
│   │   ├── ExercisePrescription.swift
│   │   ├── SetTarget.swift
│   │   ├── Load.swift
│   │   ├── ExerciseCatalogItem.swift
│   │   ├── WorkoutSession.swift
│   │   ├── SetLog.swift
│   │   ├── ReminderSettings.swift
│   │   └── ReminderSpec.swift
│   ├── Parsing/
│   │   ├── PlanJSONExtractor.swift     # 从任意文本抠出 JSON 片段
│   │   ├── PlanDecoder.swift           # JSON -> WorkoutPlan，错误定位到字段路径
│   │   ├── PlanValidator.swift         # 取值范围与一致性校验
│   │   ├── PlanNormalizer.swift        # 修补：排序、去重、clamp、补默认
│   │   ├── FreeTextPlanParser.swift    # 自由文本启发式解析
│   │   ├── ParseIssue.swift            # 问题项（路径 + 级别 + 说明）
│   │   └── ParsedPlanDraft.swift       # 校正界面用的草稿模型
│   ├── Scheduling/
│   │   ├── WeeklyScheduleGenerator.swift  # 计划 + 设置 -> [ReminderSpec]
│   │   ├── SedentaryResolver.swift        # P1：久坐时间窗 -> [Date]，本期不实现
│   │   ├── ScheduleResolver.swift         # weekday 匹配 -> 某天练哪份计划日（P1 加 adjustments）
│   │   ├── NotificationBudget.swift       # 配额与 64 条上限核算
│   │   └── CompletionRateCalculator.swift # 三态口径
│   ├── Workout/
│   │   ├── RestTimerStateMachine.swift    # 纯状态机，无 Timer
│   │   ├── WorkoutFlowModel.swift         # 组序列展开（动作/组/休息的线性序列）
│   │   └── WorkoutSessionReducer.swift    # 打卡事件 -> 记录变更
│   ├── Figure/
│   │   ├── FigureSpec.swift               # 骨架规格：12 关节名、帧坐标、props、视角
│   │   ├── FigureFrame.swift              # 帧索引计算，纯函数
│   │   ├── FigureGeometry.swift           # 关节名 -> 骨段连线表、远侧肢体判定
│   │   └── FigureAutofit.swift            # 全帧并集 bbox -> 等比缩放居中，纯函数
│   ├── Analytics/
│   │   ├── AnalyticsEvent.swift
│   │   └── AnalyticsNaming.swift          # 事件名与属性白名单
│   └── Ports/
│       ├── PlanStoring.swift
│       ├── SessionStoring.swift
│       ├── ProfileStoring.swift
│       ├── CatalogProviding.swift
│       ├── Notifying.swift
│       ├── SecretStoring.swift
│       ├── AIPlanGenerating.swift
│       └── Clock.swift
│
├── Data/
│   ├── Persistence/
│   │   ├── DongKeSchema.swift          # Schema 与 ModelContainer 构造
│   │   ├── Records/
│   │   │   ├── PlanRecord.swift
│   │   │   ├── SessionRecord.swift
│   │   │   ├── SetLogRecord.swift
│   │   │   ├── ProfileRecord.swift
│   │   │   └── ReminderSettingsRecord.swift
│   │   └── Mapping/
│   │       ├── PlanRecord+Domain.swift
│   │       ├── SessionRecord+Domain.swift
│   │       ├── SetLogRecord+Domain.swift
│   │       └── ProfileRecord+Domain.swift
│   └── Repositories/
│       ├── PlanRepository.swift
│       ├── SessionRepository.swift        # 含 undo 的 active-only 断言
│       ├── ProfileRepository.swift
│       ├── ReminderRepository.swift
│       ├── AnalyticsRepository.swift      # 本地 JSONL，30 天滚动清理
│       └── CatalogRepository.swift        # 读 bundle 的 exercises.json，内存索引
│
├── Services/
│   ├── NotificationService.swift       # Notifying 实现
│   ├── KeychainService.swift           # SecretStoring 实现
│   ├── AIPlanClient.swift              # AIPlanGenerating 实现
│   ├── AIPromptBuilder.swift           # 提示词模板拼装（纯函数）
│   ├── SystemClock.swift               # Clock 实现
│   ├── HapticsService.swift
│   ├── BackupService.swift             # 计划与记录导出/导入
│   └── AppLog.swift                    # OSLog 封装，强制脱敏
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingFlowView.swift
│   │   ├── OnboardingViewModel.swift
│   │   └── Steps/                      # 每条问卷一屏，一屏一文件
│   ├── PlanImport/
│   │   ├── PlanImportView.swift
│   │   ├── PlanImportViewModel.swift
│   │   ├── PasteTextView.swift
│   │   └── AIKeySettingsView.swift
│   ├── PlanReview/
│   │   ├── PlanReviewView.swift        # 结构化预览 + 问题项高亮
│   │   ├── PlanReviewViewModel.swift
│   │   └── PlanEditSheet.swift         # 人工校正
│   ├── Today/
│   │   ├── TodayView.swift
│   │   └── TodayViewModel.swift
│   ├── Workout/
│   │   ├── WorkoutView.swift
│   │   ├── WorkoutViewModel.swift
│   │   ├── RestTimerView.swift
│   │   ├── SetRowView.swift
│   │   ├── SessionSummaryView.swift
│   │   ├── ExerciseCardSheet.swift     # 动作卡：骨架 + 要点 + 常见错误 + 低阶替代
│   │   ├── SetOutcomeSheets.swift      # 「做不动」与「跳过原因」两个 sheet
│   │   └── ExitConfirmSheet.swift      # 训练中退出确认
│   ├── Plan/
│   │   ├── PlanView.swift              # 周计划总览
│   │   └── PlanViewModel.swift
│   ├── Library/
│   │   ├── LibraryView.swift           # 动作库
│   │   ├── LibraryViewModel.swift
│   │   ├── ExerciseDetailView.swift    # 动作详情（图 + 要点 + 常见错误）
│   │   └── ExerciseDetailViewModel.swift
│   ├── History/
│   │   ├── HistoryView.swift
│   │   ├── HistoryViewModel.swift
│   │   └── CompletionChartView.swift   # Swift Charts
│   └── Settings/
│       ├── SettingsView.swift
│       ├── ReminderSettingsView.swift
│       └── DataExportView.swift
│
├── DesignSystem/
│   ├── Theme.swift                     # 语义色 token，唯一颜色来源
│   ├── Typography.swift
│   ├── Spacing.swift
│   ├── Icons.swift                     # SF Symbols 白名单枚举，唯一图标来源
│   ├── Components/
│   │   ├── PrimaryButton.swift
│   │   ├── CardSurface.swift
│   │   ├── SectionHeader.swift
│   │   ├── ProgressRing.swift
│   │   └── EmptyStateView.swift
│   └── Figures/
│       └── ExerciseFigureView.swift    # 唯一动作图渲染器，按 figure-specs 画 12 关节骨架
│
└── Resources/
    ├── Assets.xcassets                 # 仅 AppIcon 与启动色，不含动作图
    ├── exercises.json                  # 内置动作库 18 条（别名/肌群/器械/难度/要点/常见错误/figureSpecId）
    ├── figure-specs.json               # 18 个动作的 12 关节骨架数据，每动作 3 帧
    ├── design-tokens.json              # 与 docs/design-tokens.json 同源，构建时拷贝
    ├── fonts/
    │   └── B612Mono-Bold-subset.ttf    # OFL，仅倒计时与训练主数字，子集化后 <40KB
    ├── licenses/
    │   └── OFL-B612.txt                # 打包字体的 OFL 全文，随仓
    └── Localizable.xcstrings
```

### 4.3 文件组织硬规则

| # | 规则 | 不合格表现 |
|---|---|---|
| 1 | 单文件不超过 300 行（不含空行）。超限按子功能拆文件 | 一个 `WorkoutView.swift` 800 行 |
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
grep -rn "import SwiftUI" DongKe/Domain DongKe/Services DongKe/Data --include=*.swift
grep -rn "systemName:" DongKe --include=*.swift | grep -v "DesignSystem/Icons.swift"
grep -rn "Color(hex:" DongKe --include=*.swift | grep -v "DesignSystem/Theme.swift"
grep -rln "//" DongKe --include=*.swift | xargs -r grep -Hn "^\s*//"
find DongKe -name '*.swift' | xargs wc -l | awk '$1>300 && $2!="total"'
grep -rn "URLSession" DongKe --include=*.swift | grep -v "Services/AIPlanClient.swift"
grep -rn "UIPasteboard" DongKe --include=*.swift
grep -rn "removeAllPendingNotificationRequests" DongKe --include=*.swift
grep -rn "#[0-9A-Fa-f]\{6\}" DongKe --include=*.swift
```

最后四条 grep 的期望结果为空，各自对应一条架构承诺：

- `URLSession` 只允许出现在 `AIPlanClient` 里。这是"离线优先"唯一可自动验证的形式
- `UIPasteboard` 一律不出现，粘贴只能走 `UIPasteControl`
- `removeAllPendingNotificationRequests` 一律不出现，通知只能按前缀清理，见 §9.5
- 任何 6 位十六进制色值都不出现，颜色只能来自 `design-tokens.json`

任一 grep 非空，或存在超 300 行的文件、入口文件含业务逻辑，即退回重做，不算完成。

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
| `ExerciseCatalogItem` | id, name, aliases, primaryMuscles, equipment, difficulty, cues, commonMistakes, figureSpecId, defaultTarget | 只读，来自 `Resources/exercises.json`，首次启动加载进内存索引 |
| `WorkoutSession` | id, ownerId, planId, planDayId, weekday, startedAt, finishedAt, status, plannedSets, completedSets, downgradedSets, skippedSets, totalRestSeconds | 一次训练一条。三个计数分开存，完成率口径靠它们算，不靠事后遍历 |
| `SetLog` | id, ownerId, sessionId, prescriptionId, setIndex, targetType, targetValue, actualValue, outcome, skipReason, completedAt, rpe | 一组一条。**outcome 三态**：`done` / `downgraded`（降阶完成）/ `skipped`；`skipReason` 为枚举见下 |
| `SetOutcome` | `done` / `downgraded` / `skipped` | 三态是 PRD 的硬要求，不用 `isSkipped: Bool`（布尔表达不了"降阶完成"） |
| `SkipReason` | `noTime` / `tooHard` / `pain` / `noEquipment` / `other` | 跳过原因枚举。`pain` 单独一档，用于后续风险提示，不参与完成率 |
| `ScheduleAdjustment`（P1） | id, ownerId, planId, targetDate, kind(`skipAndShift` / `skipOnly`), createdAt | 记录"今天跳过并顺延"这类偏离，**不改计划本身**。**本期不实现**，模型定义保留以免 P1 迁移，见 §5.4 |
| `ReminderSettings` | workoutEnabled, leadMinutes, sedentaryEnabled, sedentaryIntervalMinutes, sedentaryWindow, sedentarySnoozeLimit, soundEnabled, overrideTimes | 两类提醒分开开关，不塞进一个 enabled |
| `SedentaryWindow`（P1） | startHour, startMinute, endHour, endMinute, weekdaysOnly | 久坐提醒的时间窗。**本期不实现**，字段留位以免 P1 迁移 |
| `ReminderSpec` | id, kind(`workout` / `sedentary` / `rest`), fireComponents, title, body, interruption, priority | 纯值对象，由排程器产出，交给 `Notifying`。`fireComponents` 直接就是 `DateComponents`，不在 NotificationService 里二次组装 |
| `AnalyticsEvent` | name, props([String: String]), occurredAt | 本地埋点事件，见 §13.4 |

所有带 `ownerId` 的模型：`ownerId` 是首次启动生成的本地匿名 UUID（`user_local_id`），本期恒等于 `"local"` 段内唯一值，不参与任何查询条件，只为 P1 云同步预留。同时所有可持久化模型带 `updatedAt`（P1 做同步冲突判定用）。**预留字段不等于预留功能**：本期不实现同步、不实现"待同步"状态、UI 不出现同步相关字样。

### 5.4 排期解析：本期只有 weekday 匹配

FROZEN-BASELINE §2 把「跳过并顺延」列为本期不做。本期的排期解析因此只有一条规则：

```swift
enum ScheduleResolver {
    static func planDay(on date: Date, plan: WorkoutPlan, calendar: Calendar) -> PlanDay?
}
```

- 入参只有 `date / plan / calendar`，纯函数、无状态、无副作用
- 返回 `plan.days` 中 `weekday` 与 `date` 匹配的那一天；不匹配返回 `nil`，界面按休息日展示
- 训练日只有「练」与「不练」两种结果，不存在顺延、补练、漂移
- `date` 到 `weekday` 的换算必须走 `Weekday.systemWeekday`，不许在各处自己算（Calendar 的 `weekday` 是 1=周日，计划的 1=周一，这条最容易写反）

P1 接回时的设计结论保留备查：把计划当不可变模板，偏离单独记 `ScheduleAdjustment`（`skipAndShift` / `skipOnly`），由 `resolveDay(on:plan:adjustments:calendar:)` 算出某天该练哪份计划日；连续跳过超过一个完整周期时顺延队列清空并回落到原始模板，避免无限漂移。本期的签名是它的退化形式（`adjustments` 恒为空），P1 加一个参数即可，调用方不改。

### 5.5 三张表分离的执行约束

`Plan`（模板）/ `WorkoutSession`（本次实际）/ `SetLog`（已完成历史）三者的写入权限严格分离：

| 表 | 可写时机 | 禁止 |
|---|---|---|
| `PlanRecord` | 用户显式保存、切换、删除 | 训练过程中被任何代码修改 |
| `SessionRecord` | `status == active` 时可改计数与 `finishedAt` | `status != active` 后只读 |
| `SetLogRecord` | 仅追加；`undo` 仅允许删除**当前 active session** 的最后一条 | 修改历史 session 的任何 `SetLog`；按 id 修改已完成记录 |

"改今天的一组"由此天然被约束在 `SetLogRecord` 的追加与 active session 的末条删除范围内，物理上碰不到昨天的历史，也碰不到计划模板。这一条要在 `SessionRepository` 里用前置断言保证，并有单测覆盖"对已 finish 的 session 调 undo 必须抛错"。

### 5.1 为什么 `ExerciseCatalogItem` 不进数据库

动作库是只读常量，MVP 为 18 条（`plan-schema.json` 的 catalogId 白名单），体积几十 KB。放进 SwiftData 只会引入"首次启动播种失败"这类失败模式，收益为零。做法：`CatalogRepository` 在 App 启动时从 bundle 解码一次，建 `[String: ExerciseCatalogItem]` 与别名倒排索引，常驻内存。用户自定义动作（`catalogId` 以 `custom_` 前缀）本期只存在计划 JSON 里，不做编辑。

### 5.2 `WorkoutFlowModel`：把计划展开成线性执行序列

训练页不能直接遍历三层嵌套结构，要一个线性序列驱动"当前第几个动作第几组"。`WorkoutFlowModel(plan:)` 在进入训练时一次性展开为 `[FlowStep]`：

```
FlowStep
├── .set(prescriptionId, setIndex, target, restAfterSec)   # 完成这一组后给 restAfterSec 秒休息
├── .roundBreak(seconds)                                   # 循环块换轮的休息
├── .blockBreak(seconds, nextBlockTitle)                    # 换块的提示
└── .finished
```

循环块展开规则：`rounds` 轮，每轮依次走 `items`，轮内动作间用 `restBetweenItemsSec`，每轮结束插一条 `.roundBreak(restBetweenRoundsSec)`（最后一轮不插）。超级组同理（`restBetweenItemsSec = 0`）。`plannedSets` 等于展开后 `.set` 的数量，写进 `WorkoutSession` 作为分母，完成率分母从此固定，改计划不影响历史。

这是纯函数，输入 `WorkoutPlan`，输出 `[FlowStep]`，必须单测（含：循环块、超级组、休息为 0、单动作日、休息日）。

---

## 6. 持久化设计

### 6.1 表结构

SwiftData 实际落库 5 张表。计划部分刻意扁平化。

**PlanRecord**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | `#Unique` |
| createdAt / updatedAt | Date | `#Index` on updatedAt |
| isActive | Bool | `#Index`，同时只有一条为 true（切换在 Repository 里做事务） |
| sourceRaw | String | `.ai` / `.pasteJSON` / `.pasteText` / `.manual` |
| schemaVersion | Int | 计划 JSON 的契约版本 |
| planJSON | Data | **完整 `WorkoutPlan` 的 JSON**，与 `plan-schema.json` 同构 |
| title | String | 冗余列，供列表展示与排序，不参与业务判断 |
| daysPerWeek | Int | 冗余列，供列表展示 |
| goalRaw | String | 冗余列 |

**SessionRecord**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | `#Unique` |
| planId / planDayId | UUID | `#Index` on planDayId |
| startedAt | Date | `#Index` |
| finishedAt | Date? | 未结束为 nil |
| statusRaw | String | active / completed / abandoned |
| plannedSets / completedSets | Int | 分母在开始时固定 |
| totalRestSeconds | Int | 统计用 |

**SetLogRecord**

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID | `#Unique` |
| sessionId | UUID | `#Index` |
| prescriptionId / setIndex | String / Int | `#Index([prescriptionId, completedAt])` 支撑"这个动作上次做了多少" |
| targetTypeRaw / targetValue / actualValue | String / Int / Int | |
| completedAt | Date | `#Index` |
| outcomeRaw | String | `done` / `downgraded` / `skipped`，三态必填 |
| skipReasonRaw | String | `outcome == .skipped` 时必填，其余为空串 |
| updatedAt | Date | 预留同步字段 |
| rpe | Int? | 可选主观强度 |

**ProfileRecord** 单行，`#Unique` 在 `singletonKey`（固定字符串 `"me"`）。字段与 `UserProfile` 一一对应，显式列，不塞 JSON：它需要参与计划生成，显式列可读性更好。

**ReminderSettingsRecord** 单行，同上。

### 6.2 为什么计划存 JSON 文档列

三点理由，都不是偏好而是有代价的判断：

1. **契约已经在手**：AI 输出、粘贴导入、备份导出都需要 `WorkoutPlan` 的 JSON。再拆成 6 张关系表，等于同一份结构维护两套映射，回归面翻倍。
2. **计划是文档，不是事实表**：一个计划内部结构强耦合（块 → 动作 → 目标），没有跨计划的按动作聚合查询需求。需要的是"整份读出、整体替换"，这正是文档存储的形状。
3. **规避 SwiftData 的已知缺陷**：`Plan → PlanDay → ExerciseBlock → ExercisePrescription` 是四层 to-many 链。SwiftData 在多关系上的级联删除存在"不删除关联数据"的已知问题，深层链上更容易触发。扁平化后，删除一个计划就是删一行。

代价与对策：无法用 SQL 直接查"所有计划里深蹲的总组数"。当前没有这个需求；若将来有，用 `planJSON` 全量解码后内存聚合（计划数量是个位数）。这一条写进 §18 的技术债清单，不提前优化。

**冗余列与 JSON 会不一致**——所以唯一写入入口是 `PlanRepository.upsert(plan:)`：先编码 JSON，再同步写冗余列，两者在同一个 `modelContext.save()` 里完成。其他任何位置不得修改 `PlanRecord` 的字段。

### 6.3 并发与删除

- 只有主线程（`@MainActor`）上下文，不建 `@ModelActor`。理由：单次写入最多几十行，主线程耗时在毫秒级；而 `@ModelActor` 内更新不触发视图刷新是 SwiftData 的已知问题，绕它需要额外机制。
- 级联删除**不依赖** `@Relationship(deleteRule: .cascade)`。`PlanRepository.delete(planId:)` 显式按顺序删除：该计划的所有 `SessionRecord` → 这些 session 的所有 `SetLogRecord` → `PlanRecord` 本身。写在 Repository 里，可在预发阶段用测试断言"删计划后 SetLog 归零"。
- `SetLogRecord` 与 `SessionRecord` 之间**不建** `@Relationship`。用 `sessionId` 外键式普通字段关联。理由同上：避免关系链，查询靠 `#Index` 与 `FetchDescriptor(predicate:)` 完全够用。

### 6.4 迁移

`DongKeSchema` 内声明 `SchemaV1`。`schemaVersion` 字段与 `plan-schema.json` 的 `schemaVersion` 分离：前者是数据库结构版本（SwiftData 管），后者是计划 JSON 契约版本（`PlanDecoder` 管）。

- 数据库结构变更走 SwiftData 的 `SchemaMigrationPlan`，新增字段一律给默认值，保证轻量迁移可过。
- 计划 JSON 契约升级到 2 时，`PlanDecoder` 按 `schemaVersion` 分派到不同解码路径，旧计划永不重写，只在新导入时用新版本。

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

`NotificationBudget.schedule(_ specs: [ReminderSpec])` 固定步骤：

1. 按 `kind` 分组，先清本组前缀下的旧条目（先清后排，避免旧计划残留与新计划叠加）
2. 校验 `dk.plan.` 条目数等于训练日数且不超过 8，不等则记 warning 并截断（正常路径不可能触发）
3. 逐条 `add()`
4. 排完后用 `pendingNotificationRequests()` 复核 `dk.plan.` 前缀下实际存在的条目数是否等于期望值

第 4 步是唯一能发现 64 条裁剪的手段，因为系统裁剪是静默的、`add()` 不报错。本期余量充足不会触发，但必须在第一版就写进去——P1 接久坐提醒后，没有它就是"训练提醒什么时候丢的都不知道"。

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

**移出 MVP**，本期通知只有训练日提醒一种。以下结论保留，供 P1 接回时直接用，不重做调研；代码不写，但 `ReminderSettings` 的时间窗字段留位（见 §5），避免 P1 时做数据库迁移。

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

`WorkoutViewModel`（`@MainActor @Observable`）持有：

- `flow: [FlowStep]`、`cursor: Int`
- `restState: RestState`
- 一个只在前台运行的 `Timer.publish(every: 0.25)`：每 tick 调 `reduce(.tick(now: clock.now))`。0.25 秒粒度是为了让环形进度不跳格，同时避免 60Hz 定时器
- `scenePhase` 变化：进后台 `invalidate()` 定时器；回前台立即补一次 `tick`，让状态机自己处理时间跨越

时长型动作（平板支撑、开合跳计时）用同一个状态机，把"休息"换成"动作计时"，`autoAdvanceToNextSet` 换成 `completeSet`。不为它写第二套逻辑。

### 10.3 锁屏与后台的明确结论

iOS 在 App 进入后台后短时间内挂起进程，`Timer` 停止。这一点没有绕过办法（`beginBackgroundTask` 只给几分钟，且用于收尾而非持续计时）。所以：

- **不做**后台长时间计时，不申请后台音频模式伪装存活（会被审核质疑，且耗电）
- 唯一手段是 `endAt` 绝对时间 + 本地通知（§9.5）
- 回前台一律按 wall clock 重算，不补齐 tick

ActivityKit 实况通知（锁屏显示倒计时且不需要 App 运行）能显著改善体验，但需要额外 Target、额外权限配置与真机调试验证，本期列 P2，不进 MVP。

### 10.4 打卡与记录

`WorkoutSessionReducer.reduce(state:event:) -> (state, [SessionMutation])`，事件：`completeSet(actual:outcome:)`、`skipSet(reason:)`、`undoLastSet`、`finish`、`abandon`。

- 每组落盘在完成的**那一刻**发生，不等训练结束。理由：健身房场景 App 可能被系统回收、来电可能打断、低电量模式可能挂起，等结束再批量写等于把用户一小时的工作押在一次写入上。
- 三态写入：`done`（按目标完成）/ `downgraded`（降阶完成，实际值低于目标或缩短时长）/ `skipped`（带 `SkipReason`）。三态分别累加到 `completedSets` / `downgradedSets` / `skippedSets`，**不共用同一个计数**。
- `undoLastSet` 仅在 `session.status == active` 时允许，删除最后一条 `SetLogRecord` 并回退对应计数。对已 `finished` / `abandoned` 的 session 调用必须抛错（`SessionRepository.undoLastSet` 前置断言）。这是"改今天的一组不得改昨天历史"的物理保证。
- `abandon` 保留已写入的 `SetLog`，`status` 标记 `abandoned`，完成率照算不特殊处理。练了一半也是练了。
- 训练开始时把 `plannedSets` 写死。中途改计划不影响这次的分母。
- 每次落盘后发一次轻量 `UIImpactFeedbackGenerator`（`.light`），`reduceMotion` 或系统关闭触感时跳过。触感是"已记录"的唯一即时反馈，不能省。
- 落盘失败（磁盘错误、容器不可写）必须冒泡到 UI 显示"这一组没有保存成功"，不吞掉。PRD §9.3 明确要求"本地数据写入失败时必须有可见提示，不静默丢数据"。

写入原子性：一次"完成一组"是一次 `modelContext.save()`，包含 `SetLogRecord` 插入 + `SessionRecord` 计数更新。两件事不在同一个 save 里会出现"日志写了但计数没涨"的错账。

---

## 11. 完成率与统计

`CompletionRateCalculator`，纯函数：

| 指标 | 定义 | 边界处理 |
|---|---|---|
| 单日完成率 | `(completedSets + downgradedSets) / plannedSets`，clamp 到 0...1 | `plannedSets == 0` 返回 `nil`，不返回 0。UI 显示 "—" 而不是 "0%"，否则休息日与失败日看起来一样 |
| 降阶率 | `downgradedSets / plannedSets`，单独展示，不摊进完成率里掩盖 | 分母 0 返回 nil |
| 跳过率 | `skippedSets / plannedSets`，`skipReason == .pain` 的跳过额外单独计数并触发一次风险提示 | 分母 0 返回 nil |
| 周完成率 | 该周完成的训练日数 / 该周计划训练日数 | 分母为 0 返回 nil |
| 动作完成率 | 该动作 `outcome != .skipped` 的组数 / 计划组数 | 计划里已删除的动作不参与 |
| 连续达标天数 | 从今天往前，日完成率 ≥ 0.8 计为达标，连续计数 | 今天未训练不算断链，从昨天起算 |
| 总训练时长 | `sum(finishedAt - startedAt)` | 未结束的 session 不计入 |

三态口径写死在 `CompletionRateCalculator` 里，UI 不得自己算。降阶完成计入完成率是 PRD 的明确定义（"（完成+降阶完成）/ 计划组数"），但降阶与跳过必须在总结页单独露出，否则用户看到的 100% 会掩盖"四组都做了但每组都减半"这件事实。

周的口径固定为**周一到周日**，用 `Calendar.current` 的 `firstWeekday` 归一化到周一，不跟随用户系统设置。理由：计划是按周一至周日生成的，统计口径必须与计划口径一致，否则周完成率会出现跨周错位。

---

## 12. 动作图示：自绘参数化骨架

### 12.1 方案：一套渲染器 + 数据

FROZEN-BASELINE 决策 6 定的是**自绘参数化骨架**，不使用第三方素材。含义是代码里只有一套渲染器，18 个动作的差异全部写在 `Resources/figure-specs.json` 里。渲染器不认识"深蹲"，只认识关节坐标。

`figure-specs.json` 的结构以设计侧交付的 `docs/figure-specs.sample.json` v2.x 为准，本文不另立一套。顶层四段：

| 段 | 用途 | 运行时是否读 |
|---|---|---|
| `$meta` | 版本、目标文件、作者、验收口径 | 否 |
| `renderRules` | 画布、autofit 参数、12 关节名、骨段连线表、骨长基准、道具画法 | 是，启动解码一次 |
| `specs[]` | 每个动作一条，按 `catalogId` 取 | 是 |
| `coverageMap` / `deliveryPlan` | 可行性判定与交付批次 | 否，只作评审依据 |

单条 `specs` 元素（`squat`，节选）：

```json
{
  "catalogId": "squat",
  "name": "深蹲",
  "view": "side",
  "loopSeconds": 2.0,
  "props": ["floor"],
  "poses": [
    {
      "phase": 0.0,
      "label": "起始位：站直，脚与肩同宽",
      "points": {
        "head": [0.47, 0.1], "neck": [0.48, 0.16], "shoulder": [0.48, 0.22],
        "hip": [0.5, 0.48], "elbowNear": [0.42, 0.35], "wristNear": [0.4, 0.47],
        "kneeNear": [0.5, 0.72], "ankleNear": [0.5, 0.94],
        "elbowFar": [0.44, 0.36], "wristFar": [0.42, 0.48],
        "kneeFar": [0.47, 0.72], "ankleFar": [0.46, 0.94]
      }
    }
  ]
}
```

约束：

- `specs` 是**列表**不是字典，取用时按 `catalogId` 建内存索引，与 `exercises.json` 的 `figureSpecId` 对齐
- 坐标是"作者空间"：归一化单位正方形、原点左上、y 向下，**允许超出 0..1**——死虫这类「平躺双臂过头 + 双腿前伸」跨度约 1.11，物理上装不进单位正方形，由 autofit 兜住（§12.3）
- 12 个关节名固定，不许多、不许少、不许改名（清单见 `renderRules.joints`）
- `poses[].phase` 是 0..1 的循环相位，帧间按相位线性插值；至少 2 个 pose 才构成动画，`_generic` 只有 1 个（静态）
- `view` 三选一：`side`（默认，面朝右）/ `front`（`jumping_jack`、`high_knees`——侧面读不出"腿打开"）/ `sideLow`（`side_plank`）
- `props` 显式声明道具：`floor` / `wall` / `dumbbell`，`wall` 另需 `wallX`。**不靠渲染器猜**：哑铃划船没有哑铃会被读成徒手俯身，靠墙静蹲没有墙会被读成半蹲，这是辨识度问题不是美术问题
- 8 关节是技术兜底不是选项：弓步蹲、开合跳、死虫、哑铃划船在 8 关节下缺远侧膝踝与肘腕，前后腿分不开。**MVP 按 12 关节验收**

### 12.2 视觉规格

参数全部来自 `renderRules`，本文只解释为什么：

| 项 | 规格 | 理由 |
|---|---|---|
| 画布 | 正方形，绘制区边长 160pt（训练页固定区的组成见 UIUX §6.5） | 200pt 会挤掉 cues，而 PRD 要求 cues 3–5 条与骨架同屏 |
| 线宽 | 画布边长的 2.2%（160pt 画布约 3.5pt）；缩略图缩到低于 2.5pt 时自动加粗到 2.5pt | 低于 2.5pt 的 1pt 级线条在斜线上会被抗锯齿吃掉，看起来"发虚" |
| 关节 | 半径 1.6% 的**挖空圆点**（填 `surfaceRaised`），必须小于线宽 × 1.2 | 实心圆点会让 12 点骨架变成"糖葫芦"；挖空才读得出线稿感，同时保留关节点以便判断角度 |
| 躯干 | `shoulder`→`hip` 连线加粗为其它骨段的 1.4 倍 | 不做躯干填充（填色会让深色模式成色块，且被读成"人体"而非"骨架"），只能靠粗细区分躯干与四肢 |
| 远侧肢体 | 所有 `*Far` 关节参与的骨段 opacity 0.55 | 表达前后遮挡。缺这一层，正面视角会读成二维对称图 |
| 颜色 | 单色 `textPrimary`；`props` 线走 `separator`；`_generic` 整体降为 `textTertiary` | 单色是为了让人看形状。双色骨架会把注意力引到"哪块肌肉"，这不是本产品的教学目标 |
| 骨长 | 同一动作各帧同名骨段必须一致，容差 ±15%，基准值在 `renderRules.segmentLengths`（torso 0.26 / thigh 0.24 / shin 0.21 / upperArm 0.15 / forearm 0.13 / neck 0.06） | 手标坐标必然有误差，超容差会在插值里表现为"橡皮筋"。这条进测试（§15），不靠肉眼 |

±15% 与 `segmentLengths` 是这套方案唯一的硬数据约束。它让"手标错了"在 CI 就红，而不是等用户看到动作变形。

### 12.3 autofit：全帧并集 bbox

对同一动作**全部 pose** 取坐标并集 bbox，等比缩放并居中到 0.06–0.94，最小缩放 0.6。参数来自 `renderRules.autofit`。

```swift
static func fit(poses: [[String: CGPoint]], in rect: CGRect, minScale: CGFloat) -> CGAffineTransform
```

- 取并集而不是逐帧 fit：逐帧 fit 会让不同帧缩放比例不同，插值时人忽大忽小
- 最小缩放 0.6：防止某个动作因为单个越界关节被整体缩到看不清
- 副作用：不同动作视觉尺寸略有差异。这是解剖正确性的代价，接受——宁可尺寸不齐，不要比例失真
- 纯函数，单测覆盖：全在框内 / 单点越界 / 跨度 1.11 的死虫 / 退化为单点（除零）/ 最小缩放触发 / 多帧取并集而非逐帧

### 12.4 帧序、播放与降级

| 项 | 做法 |
|---|---|
| 循环周期 | **按 `spec.loopSeconds`，不全局固定**。打样值 1.2–3.5 秒：`jumping_jack` 1.2（快节奏动作），`plank` 与 `wall_sit` 3.5（静力动作，慢呼吸感），其余 2.0–2.6。统一一个数字会让静力动作看起来在抖、快节奏动作看起来卡 |
| 帧索引 | `FigureFrame.index(elapsed:loopSeconds:poseCount:)` 纯函数；`elapsed` 为 0 / 整周期 / 负值 / 超大值都有单测 |
| 播放 | `TimelineView(.animation(minimumInterval: 1.0/30.0))` 驱动，pose 间交叉淡入避免跳变 |
| 播放范围 | 训练页与动作详情才播；历史列表、动作库列表一律静态首帧；同屏只允许 1 个在播 |
| 减弱动态效果 | `accessibilityReduceMotion` 为 true 时固定首帧，不播，`accessibilityLabel` 保留 |
| 无障碍 | `accessibilityLabel` 取 `ExerciseCatalogItem.cues` 首句 |
| 库外动作 | `custom_` 前缀或 `figureSpecId` 查不到规格时，渲染 `_generic` + 动作 `notes` 文本 |

`_generic` 是一条普通 specs 记录（`isPlaceholder: true`，1 个 pose，不循环，整体 `textTertiary`），走**完全相同的渲染路径**，因此没有额外代码分支。占位必须让用户看出"这是正常状态"而不是加载失败——所以用同一个渲染器画同一个中性站姿，不用系统类别图标顶替。

### 12.5 数据门禁：七项，跑在测试里

1. `specs[].catalogId` 集合 == 18 个 catalogId + `_generic`（与 `plan-schema.json` 白名单完全相等）
2. pose 数：普通动作 2–3，`_generic` 恰 1
3. 每个 pose 的 `points` 恰有 12 个关节名，且都在 `renderRules.joints` 内
4. 坐标全为有限数（拒绝 `nan` / `inf`）
5. 同动作各 pose 同名骨段长度在基准值 ±15% 内
6. `view` ∈ {side, front, sideLow}；`props` ⊆ {floor, wall, dumbbell}；`wall` 存在时必须有 `wallX`
7. `exercises.json` 每条 `figureSpecId` 都能在 `specs` 命中

第 1 条与第 7 条互为反向校验：前者少一条、后者引用挂空，都会红。**这七项写在测试里，不写在构建脚本里**——数据是手写自有资源，没有上游仓库可依赖，缺项是本项目缺陷，必须让 CI 红。

`coverageMap` 与 `renderRules.fallback8Joints` 对"8 关节能撑住几个动作"的判定不一致：前者列 11 个可用（含 `dumbbell_row`），后者说只有 6 个可用、并把哑铃划船列为做不到。交付前需设计侧统一——8 关节只是技术兜底、MVP 按 12 关节验收，不影响本期，但两个字段相反会让 P1 复用时判错。

### 12.6 要点与常见错误的来源

`ExerciseCatalogItem.cues`（3–5 条）与 `commonMistakes`（2–3 条）来自 `Resources/exercises.json`，在动作详情与动作卡 sheet 分两栏列出。骨架负责"看形状"，文字负责"看要点"，两者都要：骨架能表达躯干角度，表达不了"膝盖别内扣"。

这是自有内容，随 `exercises.json` 手写。每条要点必须具体到可执行——写"下蹲时膝盖朝脚尖方向"，不写"注意姿势"。

### 12.7 为什么不用第三方素材

素材方案（`bryllim/workout-guide`，302 动作 × 3 帧，代码 MIT、素材 CC BY-SA 4.0）在工程上更省：转换脚本跑一次就有 54 张专业线稿，省 5–8 人日手工。否决的理由是授权，不是质量：

- CC BY-SA 4.0 的 share-alike 对"集合（mere aggregation）"不生效，这一点成立；但 App Store 分发带 FairPlay 技术保护，而 CC 4.0 禁止对许可作品施加限制他人行使许可权利的技术措施。业界普遍认为应用商店 DRM 与 CC 4.0 相容，但这需要法务确认，工程拍不了板
- 一旦法务否决，54 张图全部作废并整体回退，回退成本 5–8 人日。把不可控的前置不确定性放到第 2 周才发现，比一开始就自己做更贵
- 自绘之后动作数据完全可控：加第 19 个动作只是加一条 JSON，不动代码；调某个动作的姿态只是改坐标，不受上游仓库维护状态影响

代价说清楚：自绘骨架的视觉表现低于专业线稿，且 18 个动作的手标坐标是真实工作量——§12.2 的 ±15% 容差就是为这份误差准备的。这笔账在 FROZEN-BASELINE 决策 6 处已经拍过，本文按裁决执行。

---

## 13. 安全与隐私

### 13.1 密钥与传输

| 项 | 做法 | 禁止 |
|---|---|---|
| API Key 存储 | `KeychainService`，`kSecClassGenericPassword`，`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | 存 UserDefaults、存文件、存 SwiftData、写进 plist |
| Key 展示 | 只显示末 4 位（`sk-****abcd`），输入框 `isSecureTextEntry` | 明文回显完整 Key |
| Key 写入门禁 | 保存前先发一次最小请求验证（`GET {base}/models` 或 1 token 的 chat 请求），失败不保存 | 存了才发现填错 |
| 传输 | 强制 https。Base URL 非 https 直接拒绝并提示 | 允许 http；加 `NSAllowsArbitraryLoads` |
| 日志 | `AppLog` 统一封装，打印前对 header 与 body 做脱敏（`Authorization` 一律替换为 `Bearer ***`） | `print` 请求头、`print` Key、把响应正文整段写日志 |
| 备份导出 | `BackupService.export()` 只导出计划与记录，**结构性不含任何密钥字段** | 把 Key 序列化进导出文件 |
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

### 13.4 埋点：本期只落本地，不上传

PRD §9.4 要求埋点，但本期没有自建后端，**没有任何上传通道**。这不是省略，是范围决定的现实，必须讲清楚，否则会在联调时被当成漏做：

| 项 | 本期做法 |
|---|---|
| 事件采集 | `AnalyticsEvent` 落本地（JSONL 文件，按天分片，保留 30 天滚动清理） |
| 上传 | 不做。无服务端可传 |
| 用户关闭数据分析 | 设置开关关闭后，只保留崩溃与异常类事件，业务事件不再记录 |
| 属性约束 | 只允许枚举值与聚合数字；禁止写入计划原文、动作备注明细、任何可反推身份的信息 |
| 本地标识 | `ownerId`（首次启动生成的匿名 UUID），不是设备 IDFA、不是 IDFV |

一条技术上做不到的事，必须提前说清：PRD 要求 `notification_delivered` 与 `notification_opened` 分离监控。**纯本地通知拿不到"已投递"回执**——`UNNotificationServiceExtension` 只对远程推送生效，本地通知在系统投递时不回调 App。本期只能采到 `notification_scheduled`（排程时）与 `notification_opened`（用户点开时），两者之比即打开率。若一定要投递级数据，只能引入服务端推送，与本期范围冲突，列 P1 再议。

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

### 14.4 字体：系统字体 + 一个打包等宽字体

| 角色 | 字族 | 来源 | 用途 |
|---|---|---|---|
| 标题 / 正文 / 中文 | SF Pro Display / SF Pro Text / PingFang SC | 系统 | 全部常规文本，走 Dynamic Type |
| 仪表数字 | B612 Mono Bold（OFL 打包，子集化） | `Resources/fonts/` | 仅休息倒计时与训练页主数字 |
| 等宽（非数字） | SF Mono | 系统 | 计划粘贴框、AI Key 输入 |

打包一个字体的理由是倒计时的"仪表感"：等宽数字在秒数跳动时不横向抖动。系统等宽也能不抖动，但字面偏窄、字重偏轻，88pt 下显得单薄。只打包一个字重、只用于两处，边界清楚。

打包的技术清单（缺一不可）：

1. `UIAppFonts` 填**文件名**（含扩展名），不是 PostScript 名。填错的表现是字体静默回退，不报错
2. OFL 全文随仓 `Resources/licenses/OFL-B612.txt`——OFL 要求随分发提供许可证
3. 子集化到 <40KB（只保留数字、`:`、`+`、`s` 与少量单位字符），原始 ttf 不入包
4. Reserve Font Name 声明为 `B612Mono-Bold`。OFL 允许保留原名但必须声明，不省这一步
5. 打包字体只允许出现在倒计时与训练主数字**两处**，第三处出现即门禁失败（见 §4.3 的 grep）

约束三条：

1. 倒计时是全项目唯一自定字号（88pt，上限 96pt），**不跟随 Dynamic Type**：已 88pt 再放大没有意义
2. 不跟随缩放必须补无障碍：倒计时视图设 `accessibilityLabel("休息剩余")` + `accessibilityValue("1 分 20 秒")`，**每整 10 秒更新一次**。不取 5 秒：VoiceOver 播一句要 2–3 秒，5 秒粒度会让播报排队，用户听到的是滞后的时间
3. 其余全部文本走系统文本样式派生，动态字体自动生效

包体积核算：主二进制约 8–12MB（SwiftUI + SwiftData，无第三方）。加 `figure-specs.json` 约 40–60KB、B612 子集 <40KB，总量在 12MB 以内。

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

原则：Domain 层必须 100% 可测且不依赖任何系统状态。凡需要时间的地方注入 `Clock` 协议；凡需要网络的地方注入 `AIPlanGenerating` 假实现。

### 15.1 必测清单（纯逻辑，缺一不可）

| 模块 | 必测用例 |
|---|---|
| `PlanJSONExtractor` | 代码围栏、前后说明文字、字符串内大括号、尾随逗号、全角引号、外层数组、空输入、超长输入（>64KB 直接拒绝） |
| `PlanDecoder` | 合法样本；缺字段；类型漂移（字符串 "3" 解成 Int）；未知枚举值；多余字段；`schemaVersion` 不认识 |
| `PlanValidator` | sets 越界（0、21）、restSec 越界（-1、601）、`scheduledTime` 格式错（"25:00"、"7:5"）、`days.count != 7`、`dayIndex` 重复、`daysPerWeek` 与实际训练日数不一致、`weekday` 与 `dayIndex` 不匹配 |
| `PlanNormalizer` | 缺 blocks 补空数组、重复 itemId 重编、sets clamp 到 1...20、restSec clamp 到 0...600、按 dayIndex 排序 |
| `FreeTextPlanParser` | 中文数字（三组十二次）、`3x12`、`3×12`、`12-15次`、`30秒`、`1分钟`、`每侧`、`循环3轮`、`超级组`、`热身`、无数字只有动作名、完全无关文本（返回空草稿而不是崩溃） |
| `WorkoutFlowModel` | 普通三动作日、循环块 3 轮、超级组 0 休息、休息日为 0 步、`plannedSets` 计数正确 |
| `RestTimerStateMachine` | §10.1 的 8 条不变量逐个覆盖；额外覆盖：tick 早于 endAt、正好等于 endAt、pause 后 tick 无效、extend 三段行为、skip 在 idle 态 |
| `WorkoutSessionReducer` | 完成组累加、跳过不计入 completed、undo 连续 3 次、undo 到 0 后不再减、abandon 保留已完成、finish 幂等 |
| `WeeklyScheduleGenerator` | 有时间的训练日、无时间的回退、休息日不生成训练提醒、`leadMinutes` 跨零点（00:05 提前 30 分钟） |
| `NotificationBudget` | 训练日 0 / 3 / 7 条时的生成数量；超出配额 8 时截断并记 warning；前缀不匹配的条目不被删除；`dk.plan.` 回读复核缺项能被检出 |
| `CompletionRateCalculator` | plannedSets 为 0 返回 nil；三态组合（全 done / 含 downgraded / 含 skipped / 全 skipped）；降阶计入完成率而跳过不计；`pain` 单独计数；同动作跨天；周口径固定周一起；连续达标天数在"今天未练"时的判定 |
| `SedentaryResolver`（P1，本期不写测试） | 窗内固定时刻、`weekdaysOnly` 跳过周末、跨零点窗口（22:00–06:00）、区间跨月 |
| `ScheduleResolver`（本期退化形式） | weekday 命中返回该日、不命中返回 nil、跨月跨年、计划只有 1 个训练日、周日边界（Calendar 的 1=周日 vs 计划的 1=周一） |
| `SessionRepository` 写入权限 | 对 `finished` / `abandoned` 的 session 调 undo 必须抛错；已完成 session 的 SetLog 不可被修改；一次"完成一组"的 save 是原子的（日志与计数同进同退） |
| `FigureFrame` | elapsed 为 0、整周期、相位取模（1.2 周期 → 0.2）、负数 clamp、frameCount 为 1 与 3 |
| `FigureSpec` 解码与门禁 | §12.5 七项逐条：`specs[].catalogId` 集合 == 18 + `_generic`、pose 数 2–3（`_generic` 恰 1）、关节名恰 12 个、坐标拒绝 `nan`/`inf`、骨长 ±15%、`view`/`props` 枚举与 `wallX` 存在性、`figureSpecId` 反查命中 |
| `FigureGeometry` | 12 关节 → 骨段连线表完整；`*Far` 关节判为远侧；躯干骨段加粗 1.4 倍；缺任一关节时不崩溃并返回空骨段 |
| `FigureAutofit` | 全在框内 / 单点越界 / 跨度 1.11 的死虫 / 退化为单点（除零）/ 最小缩放 0.6 触发 / 多帧取并集而非逐帧 |
| `Icons` 清单 | 白名单内每个 symbol 名称在 iOS 18.0 可用（编译期 `Image(systemName:)` 存在性靠真机验证，清单里标注可用版本） |
| `AnalyticsNaming` | 事件名全部命中 PRD §9.4 清单；属性值全部为枚举或聚合数字；拒绝写入原文类字段 |
| `Weekday.systemWeekday` | monday→2、sunday→1、saturday→7（**这一条最容易写反，必须有测试**） |
| `AIPromptBuilder` | 提示词包含全部 catalogId 白名单；包含用户伤病限制；模板中的 JSON 部分可被 `PlanJSONExtractor` 反解出结构说明 |

### 15.2 假实现与不可测边界

| 依赖 | 测试替代 |
|---|---|
| `Clock` | `FixedClock`（可控 `now`）、`ManualClock`（可推进） |
| `Notifying` | `RecordingNotifier`（记录 add/remove 调用序列与参数） |
| `AIPlanGenerating` | `StubAIPlan`（返回成功样本 / 各类 `AIClientError`） |
| `PlanStoring` 等 | 内存版 Repository，不启 SwiftData |
| `UNUserNotificationCenter` | 不 mock，单元测试不碰。真实通知行为靠真机手工验证（§19 端到端） |
| Keychain | 只在 `KeychainServiceTests` 里测，每个用例 teardown 删除自己的 key（模拟器 Keychain 跨 App 共享且跨运行保留，不清理会污染后续用例） |

### 15.3 端上 UI 验证

XCTest UI 测试只覆盖三条主链路，不做全面覆盖（成本高、稳定性差）：

1. 引导问卷走完 → 保存 → 进今日页
2. 粘贴合法 JSON → 预览 → 保存 → 今日页出现该计划
3. 粘贴非法文本 → 预览页出现橙色 issue → 手动改正 → 保存成功

性能基线：用 XCTest 的 `measure` 锚定"计划列表首次渲染"与"训练页 30 次 tick 的 CPU 占用"，作为回归门槛。

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
| 6 | SwiftData 关系链缺陷 | 删除计划后残留 SetLog，完成率统计错乱 | 计划扁平化为 JSON 列；不建 `@Relationship`；显式按序遍历删除 | 单测断言"删计划后 SetLogRecord 计数为 0" |
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
| D-20 | 动作图示素材 | **不使用第三方素材**（FROZEN 决策 6）。自绘参数化骨架，18 动作 × 3 帧 | 规避 CC BY-SA share-alike 与商店 DRM 的相容性争议；代价是 18 动作手标坐标，用渲染器 + 数据门禁压住 | `bryllim/workout-guide` 线稿（v1.1 曾采用，v1.3 撤销） |
| D-21 | 骨架数据覆盖范围 | 只做 18 个 catalogId + `_generic`，不扩到 60/302 | 与计划契约白名单严格相等；扩动作只是加 JSON 不动代码，但每个动作都要手标，留到 P1 | 60 动作全量、302 动作全量 |
| D-22 | 久坐提醒 | **移出 MVP，列 P1**。P1 形态为工作日每天 4 个固定时刻（5×4=20 条 repeating） | 间隔式要靠后台刷新重建通知，而 `BGAppRefreshTask` 时机不受保证；提醒不响比提醒不准更糟 | 间隔式提醒、本期硬塞进 MVP |
| D-23 | 通知预算 | 本期常驻 ≤7 条（仅训练日提醒），配额上限 11 条 | 64 条上限在本期不构成约束；复核机制仍保留，因 P1 接久坐后它会立刻变成必需 | 预留 27 条常驻、无复核机制 |
| D-24 | 时效性通知 | 训练与休息用 `.timeSensitive`；不申请 Critical | timeSensitive 只需 Xcode capability 无需 Apple 审批；Critical 需 Apple 单独批准且健身场景不够格 | 全部 timeSensitive、申请 Critical |
| D-25 | 通知权限时机 | 引导最后一屏之后请求 | 用户刚做完时段选择，上下文最强；训练提醒默认开，早拿权限才不会出现"默认开但排不了" | 冷启动请求、等到设置页 |
| D-26 | 打卡三态 | `done` / `downgraded` / `skipped` + 跳过原因枚举 | 布尔表达不了"降阶完成"；完成率与降阶率要分开算，否则 100% 会掩盖事实 | `isSkipped: Bool` |
| D-27 | 跳过并顺延（P1） | **本期不做**（FROZEN §2）。本期排期只有 weekday 匹配，见 §5.4 | 顺延会让"今天该练什么"依赖历史状态推导，MVP 先保证规则可解释 | 本期实现 `ScheduleAdjustment` + 链式顺延 |
| D-28 | 预留同步字段 | 加 `ownerId` / `updatedAt`，不实现同步也不做"待同步"态 | 加字段成本近零，能省一次迁移；做状态机却没有同步通道属于假功能 | 现在就设计同步状态机 |
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

开工前逐项确认，缺项不进入编码：

- [ ] 已按 §4.2 建出目录骨架，`App/AppContainer.swift` 能编译通过（空实现）
- [ ] `DongKeSchema` 的 5 张表能建库、能插入一条假数据、能读回
- [ ] `docs/plan-schema.json` 已作为资源或测试 fixture 引入测试 Target
- [ ] Domain 层的模型与端口协议全部定义完（可以先返回 `fatalError`，但签名冻结）
- [ ] 15.1 的测试清单已落成测试文件的空壳（红），按清单顺序逐个转绿
- [ ] `figure-specs.json` 已覆盖 18 个 catalogId + `_generic`，§12.5 七项门禁全绿（集合、pose 数、关节名、有限数、骨长 ±15%、枚举与 wallX、figureSpecId 反查）
- [ ] `Resources/licenses/OFL-B612.txt` 已随仓；`UIAppFonts` 填的是文件名，子集 <40KB（§14.4 五项逐条可查）
- [ ] `design-tokens.json` 已拷入 Resources 且 `Theme` 能解码出全部 28 个语义色
- [ ] 倒计时用 B612 Mono Bold 渲染且 VoiceOver 能读出剩余时间；打包字体只出现在倒计时与训练主数字两处
- [ ] Time Sensitive Notifications capability 已在 Xcode 添加，entitlements 文件已入版本库
- [ ] §14.6 三项裁决已回写本文，且本文与 `FROZEN-BASELINE.md` / `SPEC.md` 无冲突（v1.3 已回同步）

每个 Feature 完成判据：

- [ ] 有对应 ViewModel 与逻辑测试
- [ ] 无硬编码颜色、字号、图标字面量
- [ ] 单文件不超过 300 行
- [ ] `grep` 门禁 §4.3 全绿
- [ ] 该 Feature 的失败路径有对应文案，不是"出错了"
