import Foundation

public enum ReminderAuthorization: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

public enum ReminderHealth: Equatable, Sendable {
    case ok
    case disabled
    case denied
    case notDetermined
    case incomplete(missing: Int)

    public var needsAttention: Bool {
        self != .ok
    }

    public var message: String {
        switch self {
        case .ok:
            ""
        case .disabled:
            "训练提醒已关闭，到点不会响"
        case .denied:
            "通知权限被拒绝，到点不会提醒"
        case .notDetermined:
            "还没开启通知权限"
        case let .incomplete(missing):
            "计划里有 \(missing) 天没有排上提醒"
        }
    }

    public var actionTitle: String {
        switch self {
        case .ok:
            ""
        case .disabled:
            "去开启"
        case .denied:
            "去系统设置"
        case .notDetermined:
            "开启提醒"
        case .incomplete:
            "重新排程"
        }
    }
}

public enum ReminderHealthEvaluator {
    public static func evaluate(
        settingsEnabled: Bool,
        authorization: ReminderAuthorization,
        scheduledCount: Int,
        trainingDays: Int
    ) -> ReminderHealth {
        guard trainingDays > 0 else { return .ok }
        guard settingsEnabled else { return .disabled }
        switch authorization {
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            break
        }
        let missing = trainingDays - scheduledCount
        return missing > 0 ? .incomplete(missing: missing) : .ok
    }
}
