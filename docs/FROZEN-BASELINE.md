# FROZEN-BASELINE — 动刻 MVP

> 生效：2026-10-22 方案门
> 效力：与 `PRD.md` / `ARCHITECTURE.md` / `UIUX.md` / `design-tokens.json` 冲突处，**以本表 + SPEC.md 为准**。三份文档保留推演过程，不作为开发依据。

## 1. 冻结决策（12 条）

| # | 决策 | 锁定值 | 被覆盖的旧说法 |
|---|------|--------|----------------|
| 1 | 平台 | iOS 18.0+，iPhone 竖屏。界面玻璃材质走双路径：iOS 26+ 用系统原生 Liquid Glass，iOS 18 用等价材质近似（手写内高光 / 外描边 / 厚度边 / 镜面高光） | PRD 的 iOS 16；「必须抬到 iOS 26 才有玻璃」的说法 |
| 2 | 技术栈 | SwiftUI + SwiftData + Swift 6，零第三方依赖 | — |
| 3 | 计划来源 | 粘贴文本 / 粘贴 JSON / 直连 AI（BYOK）三条并列 | PM 建议「直连 AI 降 P1」 |
| 4 | 直连 AI 形态 | OpenAI 兼容 `POST {base}/chat/completions`，非流式，Key 存 Keychain | — |
| 5 | 动作库 | **18 个**（plan-schema catalogId 白名单） | PRD 的 60 个、架构的 40 个 |
| 6 | 动作图示 | **开源素材库 `bryllim/workout-guide` 的单色线条插画**（Everkinetic 重描，媒体 CC BY-SA 4.0）：302 动作、每个恰 3 帧、512×512 透明 SVG，18 个 catalogId 全覆盖；构建期把 SVG 路径转成 SwiftUI `Path`，运行期按包围盒等比适配；静力动作只取第 1 帧；白名单外用 `_generic` 占位。素材必须可换源（`FigureSource` 协议），下一顺位目标是公有领域的 `yuhonas/free-exercise-db`（The Unlicense） | 本表旧值「自绘 12 关节骨架、不使用第三方素材」；架构 D-20 的线稿方案反而被恢复 |
| 7 | 久坐提醒 | **移出 MVP，列 P1**；通知只有训练日提醒 | PRD v1.1 的久坐 P0、架构 §9.6 |
| 8 | 通知排程 | 每个训练日 1 条 `UNCalendarNotificationTrigger(repeats: true)`，单计划 **≤7 条**；不做 48 小时滚动窗口 | 架构 v1.1 的 48h 滚动 + 50 条久坐额度 |
| 9 | 通知权限时机 | 引导第 5 屏选择提醒时间后请求；拒绝不阻塞 | PRD 的「设置页才请求」 |
| 10 | 引导问卷 | **5 屏 / 10 字段**；伤病字段进第 5 屏 | PRD v1.1 的 7 屏 |
| 11 | 主色 | 深青绿 `#0E7C66`（深色 `#34B39A`）；浅色为主 + 深色完整 | PRD v1.2 的赭石 `#B4451C` |
| 12 | 打卡模型 | 三态 `done / downgraded / skipped` + `skipReason` + `plannedValue / actualValue` | 二态 `isSkipped` |

## 1.1 增补决策（2026-10-24）

方案门之后新增的两项能力，经用户口头确认，效力同 §1：

| # | 决策 | 锁定值 | 边界 |
|---|------|--------|------|
| 13 | 一句话生成 | 文字 + 语音输入；先出「我理解为」确认页，确认后才发请求；本次覆盖天数 / 时长 / 器械 / 目标，**伤病只增不减**，不写回档案 | 不做流式；不把句子写回 `UserProfile` |
| 14 | 训练语音播报 | 关键节点 + 休息最后 3 秒倒数；**默认关**、仅前台；`AVAudioSession` 用 `.ambient`，尊重静音键 | 不做后台 / 锁屏播报（要申请 audio 后台模式）；不做语音指令控制 |

## 2. 本期不做（P1 及以后）

饮食/蛋白质、久坐提醒、视频教学、跳过并顺延、60 动作库、账号/云同步/后端、社交/支付、Watch/HealthKit/Live Activity/AlarmKit、iPad/横屏。

## 3. 门禁状态

| 门 | 状态 | 证据 |
|----|------|------|
| P0-1 无 emoji 图标 | 通过（文档层） | 全量正则扫描 CLEAN |
| P0-2 无紫→粉渐变 | 通过 | 视觉层只允许两类渐变：白色镜面高光（≤14% 白）与 tint 单色径向晕（≤16% tint）；全仓无紫→粉、无彩虹渐变 |
| P0-3 无 AI 模板味 | 通过 | 文案规范 + 反例清单 |
| 方案门 | 待用户确认 | 本文件 + SPEC.md |
