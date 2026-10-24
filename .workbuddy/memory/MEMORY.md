# SportsHelper 项目长期记忆

## 测试范围（2026-10-24 用户明确要求）

改动前先跑 `scripts/test-scope.sh` 判档，**不要无脑跑 UI 测试**：

- `ui`（动了 `DongKe/`、`Shared/`、`DongKeUITests/`、`project.yml`、`DongKe.xcodeproj/`）→ 单测 + UI 16 条
- `core`（只动 `DongKeCore/`、`DongKeCoreTests/`、`Tools/`）→ 只跑单测 484 条
- `none`（纯文档）→ 都不跑，仍要过 ARCHITECTURE §4.3 门禁

`scripts/test-scope.sh --run` 会按判定直接执行。细则见 `docs/HANDOFF.md` §6.21。

## 环境

- 模拟器 UDID：`D16A8318-973E-45CE-936B-94F5FFE3E0EC`（iPhone 18 Pro），`content_size` 保持 `large`，不要设 AX3
- 推 origin 需代理：`git -c core.sshCommand="ssh -o ProxyCommand='nc -X connect -x 127.0.0.1:7890 %h %p'" push origin main`
- `ios-run.sh` 会误判 UI 套件收尾，跑 UI 直接用 `xcodebuild ... -only-testing:DongKeUITests test`
