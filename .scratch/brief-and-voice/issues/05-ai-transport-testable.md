# 05: AI 传输层可测化 + 网络桩

**What to build:** 把 HTTP 从 App 服务里挪进 Core 的可注入传输层，让 401 / 429 / 坏 JSON / 三级降级都能在单测里跑。

**Blocked by:** None (can start immediately)

**Status:** done（2026-10-24）

- [x] `AITransport`（Core）：收 `Request`（url / key / model / messages），返回 `Result`（text + 实际用到的档位）；`sender: (URLRequest) async throws -> Response` 是唯一注入点
- [x] 保持现有行为：15s / 60s 超时、ephemeral、不走缓存、`waitsForConnectivity = false`、Bearer、`json_schema → json_object → plain`、可重试错误退避 2 秒后重试一次
- [x] `AIPlanClient` 退化成薄壳：读 `AISettingsStore` → 组 `AITransport.Request` → `transport.generate` → `AIPlanInterpreter.interpret(…, memory:, exercises:)`
- [x] 桩覆盖 15 条：200 合法 / 400 提到 response_format 降级 / 400 与格式无关不降级 / 三档全拒 / 401 / 403 / 429 重试后仍失败 / 429 重试后恢复 / 5xx 重试 / 200 空内容 / 200 非 chat-completion / 超时 / 其它 URLError / 从指定档位起步 / 请求头与三档请求体
- [x] 断言请求：`Authorization: Bearer …`、`Content-Type: application/json`、`POST`、`json_schema` 与 `json_object` 的 `response_format`、`plain` 不带 `response_format`
- [x] 不允许真实网络：桩脚本用完直接抛 `transport("脚本已用完")`，测试不会外连
- [x] `Tools/AISmoke` 改吃同一个 `AITransport`，删掉它自己那份降级环与「解析时忘了传 memory」的隐患

**两处与票面不同，记下原因**：

1. **没用 `URLProtocol`，改成注入 `sender` 闭包**。`URLProtocol` 只能拦 `URLSession.shared` 这一层，测试还得维护一个全局注册表、跟并发抢状态；闭包注入是同一语义的更小接缝，`Response(status:body:)` 也免去在测试里拼 `HTTPURLResponse`。真实 `URLSession` 的接线现在只剩 `AITransport.live` 三行，由 `scripts/ai-smoke.sh` 打真实端点覆盖。
2. **`sleep` 也可注入**。重试退避是 2 秒，不可注入的话单测要真等。测试传 `.milliseconds(1)` 并记录调用次数，用来区分「重试了」和「没重试」。

**留下的边界**：Core 里不做重试次数配置（固定一次）；`plain` 档若模型仍返回散文，仍由 `PlanImportService` 的自由文本兜底，不在传输层重试。
