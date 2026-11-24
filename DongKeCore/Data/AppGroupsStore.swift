import Foundation

/// App Group 容器里的本地持久化。
///
/// **它不是跨设备共享盘。** App Group 只在同一台设备上的 App 与扩展之间共享；
/// iPhone 与 Watch 是两个设备，文件不互通。跨设备同步走 WatchConnectivity，
/// 这里只负责「每个设备自己那一份」：会话快照 + 待发日志队列（outbox）。
public struct AppGroupsStore: Sendable {
    public static let containerID = "group.com.dongke.shared"
    public static let workoutsDirectoryName = "workouts"
    public static let pendingLogsFileName = "pending-logs.jsonl"
    public static let watchContextFileName = "watch-context.json"

    /// 每个设备本地容器。取不到（没有 entitlement / 非 App 进程）时所有操作抛
    /// `AppGroupsError.containerNotAvailable`；调用方按「同步不可用」降级。
    public static let live = AppGroupsStore(
        containerURL: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: containerID)
    )

    private let containerURL: URL?

    public init(containerURL: URL?) {
        self.containerURL = containerURL
    }

    public var isAvailable: Bool {
        containerURL != nil
    }

    // MARK: - Checkpoint

    public func saveCheckpoint(_ checkpoint: WorkoutCheckpoint) throws {
        let url = try checkpointURL(sessionId: checkpoint.sessionId, createDirectory: true)
        let data = try JSONEncoder().encode(checkpoint)
        try data.write(to: url, options: .atomic)
    }

    public func loadCheckpoint(sessionId: UUID) throws -> WorkoutCheckpoint? {
        let url = try checkpointURL(sessionId: sessionId, createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorkoutCheckpoint.self, from: data)
    }

    public func removeCheckpoint(sessionId: UUID) throws {
        let url = try checkpointURL(sessionId: sessionId, createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - WatchContext

    public func saveWatchContext(_ context: WatchContext) throws {
        let url = try watchContextURL(createDirectory: true)
        let data = try JSONEncoder().encode(context)
        try data.write(to: url, options: .atomic)
    }

    public func loadWatchContext() throws -> WatchContext? {
        let url = try watchContextURL(createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WatchContext.self, from: data)
    }

    public func removeWatchContext() throws {
        let url = try watchContextURL(createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - 待发日志（JSON Lines，跨进程追加）

    /// 追加一行。`O_APPEND` + `flock(LOCK_EX)`：Watch 与 iPhone 各自进程同时写也不会撕行。
    public func appendPendingLog(
        _ log: SetLog,
        sourceDevice: LogSourceDevice,
        at timestamp: Date = Date()
    ) throws {
        let entry = PendingSetLog(log: log, sourceDevice: sourceDevice, timestamp: timestamp)
        let line = try Self.makeEncoder().encode(entry) + Data([0x0A])
        let url = try pendingLogsURL(createDirectory: true)
        try withLockedFile(at: url, flags: O_WRONLY | O_CREAT | O_APPEND, lock: LOCK_EX) { fd in
            try Self.writeAll(fd, line)
        }
    }

    /// 读全部待发日志。坏行（写到一半被杀、编码漂移）跳过而不是整份失败，
    /// 否则一行坏数据会永久堵住同步。
    public func readPendingLogs() throws -> [PendingSetLog] {
        let url = try pendingLogsURL(createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try withLockedFile(at: url, flags: O_RDONLY, lock: LOCK_SH) { fd in
            Self.decodeLines(try Self.readAll(fd))
        }
    }

    /// 整份重写。用于「落库后清掉已同步的记录」。
    /// 与读共用同一把排他锁：写入期间不会有人读到截断中的文件。
    public func replacePendingLogs(_ entries: [PendingSetLog]) throws {
        let url = try pendingLogsURL(createDirectory: true)
        var payload = Data()
        let encoder = Self.makeEncoder()
        for entry in entries {
            payload.append(try encoder.encode(entry))
            payload.append(0x0A)
        }
        try withLockedFile(at: url, flags: O_RDWR | O_CREAT, lock: LOCK_EX) { fd in
            try Self.rewrite(fd, with: payload)
        }
    }

    /// 在锁内读—过滤—重写，避免「读完之后 Watch 又追加一行，重写把它抹掉」。
    public func removePendingLogs(where shouldRemove: (PendingSetLog) -> Bool) throws {
        let url = try pendingLogsURL(createDirectory: true)
        try withLockedFile(at: url, flags: O_RDWR | O_CREAT, lock: LOCK_EX) { fd in
            let entries = Self.decodeLines(try Self.readAll(fd))
            let kept = entries.filter { !shouldRemove($0) }
            guard kept.count != entries.count else { return }
            var payload = Data()
            let encoder = Self.makeEncoder()
            for entry in kept {
                payload.append(try encoder.encode(entry))
                payload.append(0x0A)
            }
            try Self.rewrite(fd, with: payload)
        }
    }

    /// 把一条「已交给 WCSession、但最终没送出去」的日志放回队列。
    ///
    /// 判重按账本键（会话 + 处方 + 组号 + 来源）：同一条被重投多次也只留一行，
    /// 否则每次传输失败都会在文件里多写一份，下次 flush 一起发出去，
    /// iPhone 侧虽然幂等，但 Watch 这边会一直显示「待同步 2 组」吓人。
    public func requeuePendingLog(_ entry: PendingSetLog) throws {
        let url = try pendingLogsURL(createDirectory: true)
        let key = SetLogKey(entry.log)
        try withLockedFile(at: url, flags: O_RDWR | O_CREAT, lock: LOCK_EX) { fd in
            let existing = Self.decodeLines(try Self.readAll(fd))
            guard !existing.contains(where: { SetLogKey($0.log) == key }) else { return }
            var payload = try Self.makeEncoder().encode(entry)
            payload.append(0x0A)
            try Self.writeAll(fd, payload)
        }
    }

    public func clearPendingLogs() throws {
        let url = try pendingLogsURL(createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        // 截断而不是删文件：另一个进程可能已经打开同一个 inode，
        // 删掉会让它继续写进「已从目录消失」的文件，日志就静默丢了。
        try withLockedFile(at: url, flags: O_RDWR, lock: LOCK_EX) { fd in
            guard ftruncate(fd, 0) == 0 else { throw AppGroupsError.writeFailed }
        }
    }

    // MARK: - 清理

    public func clearAll() throws {
        guard let containerURL else { throw AppGroupsError.containerNotAvailable }
        let workouts = containerURL.appendingPathComponent(Self.workoutsDirectoryName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: workouts.path) else { return }
        try FileManager.default.removeItem(at: workouts)
    }

    // MARK: - 路径

    private func containerDirectory() throws -> URL {
        guard let containerURL else { throw AppGroupsError.containerNotAvailable }
        return containerURL
    }

    private func workoutsDirectory(create: Bool) throws -> URL {
        let url = try containerDirectory()
            .appendingPathComponent(Self.workoutsDirectoryName, isDirectory: true)
        if create {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private func checkpointURL(sessionId: UUID, createDirectory: Bool) throws -> URL {
        try workoutsDirectory(create: createDirectory)
            .appendingPathComponent("checkpoint-\(sessionId.uuidString).json")
    }

    private func pendingLogsURL(createDirectory: Bool) throws -> URL {
        try workoutsDirectory(create: createDirectory)
            .appendingPathComponent(Self.pendingLogsFileName)
    }

    private func watchContextURL(createDirectory: Bool) throws -> URL {
        try workoutsDirectory(create: createDirectory)
            .appendingPathComponent(Self.watchContextFileName)
    }

    // MARK: - POSIX 文件锁

    private func withLockedFile<T>(
        at url: URL,
        flags: Int32,
        lock: Int32,
        _ body: (Int32) throws -> T
    ) throws -> T {
        let fd = open(url.path, flags, mode_t(0o644))
        guard fd >= 0 else { throw AppGroupsError.writeFailed }
        defer { close(fd) }

        guard flock(fd, lock) == 0 else { throw AppGroupsError.lockFailed }
        defer { flock(fd, LOCK_UN) }

        return try body(fd)
    }

    private static func readAll(_ fd: Int32) throws -> Data {
        guard lseek(fd, 0, SEEK_SET) >= 0 else { throw AppGroupsError.readFailed }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let count = buffer.withUnsafeMutableBytes { raw in
                read(fd, raw.baseAddress, raw.count)
            }
            if count < 0 { throw AppGroupsError.readFailed }
            if count == 0 { break }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }

    private static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let count = write(fd, raw.baseAddress?.advanced(by: offset), raw.count - offset)
                if count <= 0 { throw AppGroupsError.writeFailed }
                offset += count
            }
        }
    }

    private static func rewrite(_ fd: Int32, with payload: Data) throws {
        guard ftruncate(fd, 0) == 0, lseek(fd, 0, SEEK_SET) >= 0 else {
            throw AppGroupsError.writeFailed
        }
        try writeAll(fd, payload)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func decodeLines(_ data: Data) -> [PendingSetLog] {
        let decoder = JSONDecoder()
        return data.split(separator: 0x0A).compactMap { line in
            try? decoder.decode(PendingSetLog.self, from: Data(line))
        }
    }
}

/// 一条待同步的组日志。`SetLog` 本身没有来源设备字段——那是同步层的事，
/// 不写进 SwiftData，避免为了同步给五张表都加一列。
public struct PendingSetLog: Codable, Equatable, Sendable {
    public var log: SetLog
    public var sourceDevice: LogSourceDevice
    public var timestamp: Date

    public init(log: SetLog, sourceDevice: LogSourceDevice, timestamp: Date = Date()) {
        self.log = log
        self.sourceDevice = sourceDevice
        self.timestamp = timestamp
    }
}

public enum LogSourceDevice: String, Codable, Sendable {
    case iphone
    case watch
}

public enum AppGroupsError: LocalizedError {
    case containerNotAvailable
    case invalidFormat
    case readFailed
    case writeFailed
    case lockFailed

    public var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return "App Group container 不可用（缺少 entitlement）"
        case .invalidFormat:
            return "App Group 数据格式无效"
        case .readFailed:
            return "读取 App Group 数据失败"
        case .writeFailed:
            return "写入 App Group 数据失败"
        case .lockFailed:
            return "App Group 文件加锁失败"
        }
    }
}
