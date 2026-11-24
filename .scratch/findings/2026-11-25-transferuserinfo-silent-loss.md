# transferUserInfo 的返回值不是送达回执

日期：2026-11-25
位置：`DongKeCore/Watch/PendingLogSync.swift`、`DongKeWatch/WatchLogSender.swift`、`DongKeWatch/WatchSyncService.swift`

## 前因

W2.3 做 Watch → iPhone 的组日志回传时，`flush` 写的是「`sender.send` 没抛错就从 outbox 删」，
循环跑完 `return .sent(count)`，UI 随即显示「已同步（N 组）」。

## 本质

`WCSession.transferUserInfo` 是**排队投递**。它把 payload 交给系统的传输队列，
App 被杀也会继续传——但「交给队列」和「送达对端」是两件事。后者只体现在
`session(_:didFinishUserInfoTransfer:error:)` 的 error 参数里。

W2.3 的代码把「已排队」当成了「已送达」：任何一次传输失败，那组日志在 Watch 侧
已经删掉、UI 已经显示成功，iPhone 上什么都没有。用户无法察觉——他不会去核对
历史页少没少一组。

## 证据

| 项 | 内容 |
|---|---|
| 修复前 | `try await sender.send(entry)` → `sent.append(entry)` → 循环结束 `removePendingLogs` |
| 修复前 | 全仓库搜 `didFinishUserInfoTransfer`：**0 处实现** |
| 修复后 | `WatchSyncService` 实现回调，error 非空时 `queue.requeue(entry)` 并立即重试一次 |
| 判重 | 按账本键 `SetLogKey`（会话 + 处方 + 组号 + 来源），重投多次只留一行 |
| 变异验证 | 去掉判重 `guard`，`requeueIsIdempotent` 立刻红：`pendingCount() == 1` 实际为 3 |
| 单测 | 964 条全绿（新增 2 条）；Watch target `CODE_SIGNING_ALLOWED=NO` 编译通过 |

抓这个 bug 用了一次变异测试才确认判重不是假保护——只跑「回滚后能重发」那条用例，
去掉判重它照样绿，因为那条测试只关心条数从 0 到 1。

## 代价

从 W2.3 提交（2026-11-24）到修复（2026-11-25），代码在 main 上停了约一天。
这段时间真机一次没跑（无证书、无配对设备），所以没有实际丢过用户数据，
但风险窗口是开着的。

真正的代价在验收顺序上：如果先做 W2.7 真机清单再修这个，真机丢日志会被
误判成「App Group 没配对好」，排查方向会偏到 entitlement 上去。

## 影响面

只影响 Watch → iPhone 的组日志回传。反方向（iPhone → Watch 的上下文）走
`updateApplicationContext`，是最新状态覆盖、天然幂等，不受影响。

## 如果重来

凡是「交给异步传输层」的 API，动手前先问一句：**成功回调在哪？**

`transferUserInfo`、`sendMessage`、`URLSession` 的后台上传都是这个形状——
返回值只代表入队。把「已入队」和「已送达」分成两个状态，是这类 API 唯一安全的用法。
