# SportsHelper 项目长期记忆

## 测试范围（2026-10-24 用户明确要求）

**UI 测试默认不跑**——一轮 6 分钟。日常只跑单测，UI 显式 `--with-ui` 才跑：

- `ui`（动了 `DongKe/`、`Shared/`、`DongKeUITests/`、`project.yml`、`DongKe.xcodeproj/`）→ `--run` 只跑单测 487 条，`--with-ui` 追加 UI 16 条
- `core`（只动 `DongKeCore/`、`DongKeCoreTests/`、`Tools/`）→ 只跑单测
- `none`（纯文档）→ 都不跑，仍要过 ARCHITECTURE §4.3 门禁

该补跑 UI 的四个节点：提交前动过视图 / 改了命中区 / 改了播报或语音输入 / 要上真机。细则见 `docs/HANDOFF.md` §6.21。

## 按钮命中区（2026-10-24）

`Text` 的命中区只有字形，`frame(maxWidth:)` 与 `background` 都**不扩大**可点范围，必须 `.contentShape(Rectangle())`。统一在 `PressableGlassStyle` 里加，新按钮不要直接用 `.buttonStyle(.plain)` 配 `Text` + `frame`。

查同类问题别按视图结构扫遮挡（会把按钮内 `Text`、祖先容器全算成遮挡，误报一堆），直接量 `element.frame` 对比视觉尺寸。UI 测试断言行为、不断言结构。见 §6.22。

## 播报文案口径（2026-10-24）

- 「组」只在两个尺度出现：开始语是全天总量，每组是**该动作的累计**序号，同一句不混用
- 动作名前置：`俯卧撑，第 2 组，共 3 组，10 次`
- 跨区块休息报**下一个动作**，不是区块名
- 循环 / 超级组的累计口径在 `WorkoutFlowModel.setCounts`，UI 与播报共用

改文案后必跑 `scripts/voice-dump.sh` 复核三种（现四种）计划形态。见 §6.23。

## 环境

- 模拟器 UDID：`D16A8318-973E-45CE-936B-94F5FFE3E0EC`（iPhone 18 Pro），`content_size` 保持 `large`，不要设 AX3
- 推 origin 需代理：`git -c core.sshCommand="ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'" push origin main`
- `ios-run.sh` 会误判 UI 套件收尾，跑 UI 直接用 `xcodebuild ... -only-testing:DongKeUITests test`
