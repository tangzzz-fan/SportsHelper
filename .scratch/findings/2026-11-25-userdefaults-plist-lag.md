# 模拟器里读 UserDefaults plist 会读到旧值

日期：2026-11-25
场景：验证「手表重新开始」的 `abandonAndCreate` 是否真的把断点写成了新会话

## 现象

用 `DK_WATCH_INTENT=restart` 启动后：

- 界面截图：训练页「第 1 组 / 共 4 组」——新的空会话，符合预期
- 读 `Library/Preferences/app.dongke.ios.plist` 里的 `dk.workout.checkpoint`：
  `sessionId` 还是旧的、`stepIndex` 还是 3

两者矛盾。差一点判成「`abandonAndCreate` 只改了内存、没落盘」。

## 本质

`UserDefaults.set` 写的是进程内的缓存，磁盘上的 plist 由 `cfprefsd` 异步刷。
App 还在运行时直接读 plist 文件，读到的是**上一次刷盘**的快照。

`xcrun simctl terminate` 会走正常退出流程，这时才同步。之后读到的
`sessionId` 是新值、`stepIndex` 是 0。

## 代价

4 次工具调用：读 plist → 怀疑 → 截图 → 杀进程再读。
中途已经在想要不要给 `apply` 加日志。

## 影响

所有「从模拟器容器里读 UserDefaults 验证行为」的场景。特别是验证那些
「刚发生、App 还在跑」的写入——正是最需要验证的时刻。

## 如果重来

**读 plist 之前先 `terminate`**，或者干脆只信界面与 os_log。
要读运行中的实时状态，走 App Group 里的 JSON（`CheckpointStore` 是直接
写文件的，不经过 cfprefsd），那里没有这层缓存。

注：App Group 那份在模拟器上需要 entitlement，没配时会静默降级，所以
在模拟器里通常只剩 UserDefaults 这一份可查——更要注意 flush 时机。
