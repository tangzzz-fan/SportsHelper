# 换机接手说明

本文是给人看的交接单，不是规范。规范只有两份：`docs/FROZEN-BASELINE.md` 与 `docs/SPEC.md`。

## 1. 当前状态

| 项 | 状态 |
|---|---|
| 方案门 | 已放行（用户「方案通过」） |
| 文档 | 已冻结。PRD / ARCHITECTURE / UIUX 只作存档依据，冲突时以 FROZEN + SPEC 为准 |
| 工程 | `project.yml`（XcodeGen）已可生成 `DongKe.xcodeproj`；DongKeCore framework + DongKe app + DongKeCoreTests |
| 代码 | 只有 Domain 模型与空实现桩；UI 仅占位 `Text("动刻")` |
| 测试 | 52 条 Swift Testing，38 红 / 14 绿，红基线见 `docs/GATE-2-TEST-REPORT.md` |
| Gate 2 | 报告已提交，**等用户放行**。放行后才允许逐层转绿并写 UI |
| 远端 | `git@github.com:tangzzz-fan/SportsHelper.git`，main |

## 2. 新机器要装什么

| 依赖 | 要求 | 为什么 |
|---|---|---|
| Xcode | 27.1（iOS 27 SDK） | 目标 iOS 18.0，Swift 6 language mode + 完整并发检查 |
| XcodeGen | 任意近期版本，`brew install xcodegen` | 工程文件由 `project.yml` 生成，`.xcodeproj` 不入库 |
| iOS 18 模拟器 | 任一 iPhone 机型 | 跑测试与截图 |
| Git | 能推 https 或 ssh | 续提交。https 偶发 `HTTP2 framing layer`，遇错加 `--http1.1` |

零第三方依赖，不需要 CocoaPods / SPM 拉包。

## 3. 装完先验三件事

```bash
git clone https://github.com/tangzzz-fan/SportsHelper.git && cd SportsHelper
xcodegen generate
xcodebuild -project DongKe.xcodeproj -scheme DongKe \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

预期：生成工程成功；测试跑完 52 条，38 失败 14 通过。**这个红是基线，不是环境坏了。**

## 4. 专家团怎么续上

专家团本身跟着账号走，不跟着机器走；但**团队成员的对话上下文不迁移**——换机后是全新的三个角色，它们只知道你这次告诉它们的东西。

1. 新机器装 WorkBuddy，登录同一账号。
2. 左侧「专家」→ 选 `MvpDevExpertTeam`（与旧机同一个专家包）。
3. 首条消息把下面这段整套粘进去，不要只说「继续」：

> 接手动刻（DongKe）项目，仓库已 clone 在本机。先按顺序读：`docs/HANDOFF.md`（本文件）、`docs/FROZEN-BASELINE.md`、`docs/SPEC.md`、`docs/GATE-2-TEST-REPORT.md`、`.workbuddy/memory/2026-10-22.md`。
> 铁律：开发唯一依据是 FROZEN + SPEC，PRD / ARCHITECTURE / UIUX 只作存档，不许再跨角色对账或改写文档。
> 现状：文档已冻结，Gate 2 报告已出，52 条测试 38 红，等用户放行。
> 现在只做一件事：复述你读到的 MVP 范围、三条硬口径（字体零打包 / 占位键 `_generic` / 帧数动态 3 静力 2），以及红转绿顺序，然后停下等我放行。不要写代码，不要改文档。

第 4 步是刻意设计的验收：让新团队先复述，确认它读的是文件当前版本而不是旧记忆。旧机上反复出现的返工，全部来自角色凭记忆对账。

## 5. 已定的三条硬口径

不要在新环境重新讨论这三条，改口径等于返工：

| 口径 | 结论 | 位置 |
|---|---|---|
| 字体 | 零打包。`UIAppFonts` 为空，仓库无字体文件；倒计时用系统等宽 + `.monospacedDigit()`；字号与字族只在 `Theme/Typography.swift` 出现；88pt 是全项目唯一自定字号 | SPEC §4 / §8、ARCH §14.4 |
| 占位骨架键名 | `_generic`（不是 catalogId，下划线前缀保住「白名单严格等于 18 个」） | ARCH §12.5 第 1 条 |
| 骨架帧数 | 动态动作恰 3 帧（起始 / 最吃力点 / 回起始），`staticHold: true` 的静力动作恰 2 帧，`_generic` 恰 1 帧 | ARCH §12.5 第 2 条 |

其余冻结项见 `docs/FROZEN-BASELINE.md` 的 12 条决策。

## 6. 目录约定

| 路径 | 说明 |
|---|---|
| `docs/` | 规范与样本。`FROZEN-BASELINE.md`、`SPEC.md` 是上位依据 |
| `DongKeCore/` | Domain：模型、解析、排程、休息状态机、骨架插值。只 import Foundation |
| `DongKe/` | App 层：Features / Services / Data / App |
| `DongKeCoreTests/` | Swift Testing，纯逻辑，不依赖模拟器 UI |
| `.workbuddy/memory/` | 工作日志，**已纳入 git**，换机随仓库带走 |

## 7. 换机后容易踩的三个坑

1. **`.xcodeproj` 不在库里**：只 clone 不跑 `xcodegen generate`，Xcode 打开一片空白。
2. **把 38 条红当环境问题**：先看 `docs/GATE-2-TEST-REPORT.md` 的红转绿顺序，空实现桩本来就是红的。
3. **骨架门禁红被当成回归**：打样期数据只有 2 帧，动态动作欠第 3 帧。判红前先核对 `figure-specs` 数据版本，见 SPEC §11 最后一条。
