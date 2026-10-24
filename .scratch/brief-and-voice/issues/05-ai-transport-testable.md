# 05: AI 传输层可测化 + 网络桩

**What to build:** 把 HTTP 从 App 视图层挪到可注入的 Core 服务，让 401 / 429 / 坏 JSON / 三级降级都能在单测里跑。

**Blocked by:** None (can start immediately)

**Status:** todo

- [ ] `AIPlanService`（Core）：`AIConfiguration` + `URLSession` 注入；`AIPlanClient` 退化为读 `AISettingsStore` 的薄壳
- [ ] 保持现有行为：15s / 60s 超时、ephemeral、非流式、Bearer、`json_schema → json_object → plain`
- [ ] `URLProtocol` 桩：200 合法、200 围栏 JSON、200 散文包裹、200 垃圾、401、429（重试一次后成功 / 仍失败）、500、超时、>64KB、schema 模式被拒后降级
- [ ] 断言请求体：模型、messages 两条、temperature 0.2、无 `stream` / `max_tokens`
- [ ] 不允许真实网络：桩未命中时测试失败而不是外连

**边界**：本轮不做流式、不做多端点、不做代理；只把现有行为锁进测试。
