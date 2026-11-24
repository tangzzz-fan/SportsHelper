import Foundation

public struct AppGroupsStore {
    private static let containerID = "group.com.dongke.shared"
    private static let workoutsDir = "workouts"

    public static let shared = AppGroupsStore()

    private let fileManager = FileManager.default
    private let containerURL: URL?

    init() {
        self.containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.containerID)
    }

    // MARK: - Checkpoint 操作

    public func saveCheckpoint(_ checkpoint: WorkoutCheckpoint, sessionId: UUID) throws {
        guard let baseURL = containerURL else {
            throw AppGroupsError.containerNotAvailable
        }

        let workoutsURL = baseURL.appendingPathComponent(Self.workoutsDir, isDirectory: true)
        try fileManager.createDirectory(at: workoutsURL, withIntermediateDirectories: true)

        let checkpointURL = workoutsURL.appendingPathComponent("checkpoint-\(sessionId.uuidString).json")
        let data = try JSONEncoder().encode(checkpoint)
        try data.write(to: checkpointURL, options: .atomic)
    }

    public func loadCheckpoint(sessionId: UUID) throws -> WorkoutCheckpoint? {
        guard let baseURL = containerURL else {
            throw AppGroupsError.containerNotAvailable
        }

        let checkpointURL = baseURL
            .appendingPathComponent(Self.workoutsDir, isDirectory: true)
            .appendingPathComponent("checkpoint-\(sessionId.uuidString).json")

        guard fileManager.fileExists(atPath: checkpointURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: checkpointURL)
        return try JSONDecoder().decode(WorkoutCheckpoint.self, from: data)
    }

    // MARK: - 日志操作（JSON Lines 格式）

    public func appendPendingLog(_ log: SetLog, sourceDevice: String) throws {
        guard let baseURL = containerURL else {
            throw AppGroupsError.containerNotAvailable
        }

        let workoutsURL = baseURL.appendingPathComponent(Self.workoutsDir, isDirectory: true)
        try fileManager.createDirectory(at: workoutsURL, withIntermediateDirectories: true)

        let logsURL = workoutsURL.appendingPathComponent("pending-logs.jsonl")

        // 构造日志条目（带来源设备）
        var logDict = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(log),
            options: []
        ) as? [String: Any] ?? [:]
        logDict["sourceDevice"] = sourceDevice
        logDict["timestamp"] = ISO8601DateFormatter().string(from: Date())

        let jsonLine = try JSONSerialization.data(withJSONObject: logDict, options: [])
        let lineString = String(data: jsonLine, encoding: .utf8) ?? "{}"

        // 追加（不覆盖）
        if fileManager.fileExists(atPath: logsURL.path) {
            if let fileHandle = FileHandle(forWritingAtPath: logsURL.path) {
                fileHandle.seekToEndOfFile()
                fileHandle.write("\n".data(using: .utf8) ?? Data())
                fileHandle.write(lineString.data(using: .utf8) ?? Data())
                try fileHandle.close()
            }
        } else {
            try lineString.write(to: logsURL, atomically: true, encoding: .utf8)
        }
    }

    public func readPendingLogs() throws -> [SetLog] {
        guard let baseURL = containerURL else {
            throw AppGroupsError.containerNotAvailable
        }

        let logsURL = baseURL
            .appendingPathComponent(Self.workoutsDir, isDirectory: true)
            .appendingPathComponent("pending-logs.jsonl")

        guard fileManager.fileExists(atPath: logsURL.path) else {
            return []
        }

        let content = try String(contentsOf: logsURL, encoding: .utf8)
        let lines = content.split(separator: "\n").map(String.init)

        var logs: [SetLog] = []
        for line in lines {
            if let data = line.data(using: .utf8),
               let log = try? JSONDecoder().decode(SetLog.self, from: data) {
                logs.append(log)
            }
        }
        return logs
    }

    public func clearPendingLogs() throws {
        guard let baseURL = containerURL else {
            throw AppGroupsError.containerNotAvailable
        }

        let logsURL = baseURL
            .appendingPathComponent(Self.workoutsDir, isDirectory: true)
            .appendingPathComponent("pending-logs.jsonl")

        if fileManager.fileExists(atPath: logsURL.path) {
            try fileManager.removeItem(at: logsURL)
        }
    }

    // MARK: - 清理

    public func removeCheckpoint(sessionId: UUID) throws {
        guard let baseURL = containerURL else {
            throw AppGroupsError.containerNotAvailable
        }

        let checkpointURL = baseURL
            .appendingPathComponent(Self.workoutsDir, isDirectory: true)
            .appendingPathComponent("checkpoint-\(sessionId.uuidString).json")

        if fileManager.fileExists(atPath: checkpointURL.path) {
            try fileManager.removeItem(at: checkpointURL)
        }
    }
}

public enum AppGroupsError: LocalizedError {
    case containerNotAvailable
    case invalidFormat
    case readFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .containerNotAvailable:
            return "AppGroups container not available"
        case .invalidFormat:
            return "Invalid JSON format"
        case .readFailed:
            return "Failed to read from AppGroups"
        case .writeFailed:
            return "Failed to write to AppGroups"
        }
    }
}
