import Foundation

/// 内存里正在进行的那一次训练。
///
/// 不直接用 `WorkoutCheckpoint` 当输入：刚点「开始」、一组还没记的会话没有断点，
/// 拿 checkpoint 判会让「已经开始了」变成「什么都没有」，于是又建一个。
public struct ActiveSession: Equatable, Sendable {
    public var id: UUID
    public var dayIndex: Int
    public var startedAt: Date
    /// nil = 还没记过任何一组。
    public var checkpoint: WorkoutCheckpoint?

    public init(id: UUID, dayIndex: Int, startedAt: Date, checkpoint: WorkoutCheckpoint? = nil) {
        self.id = id
        self.dayIndex = dayIndex
        self.startedAt = startedAt
        self.checkpoint = checkpoint
    }
}

/// 这一次训练是谁发起的。只影响历史页的标注与统计，不影响任何裁决。
public enum SessionOrigin: String, Codable, Equatable, Sendable {
    case phone
    case watch
}

public enum SessionIntent: Equatable, Sendable {
    /// 今日页「开始训练」，或者「只剩 N 分钟」的短版——两者选的是同一节，
    /// 差别只在构造会话时用不用压缩过的计划，那是调用方的事。
    case startToday
    /// 点了一条带 `dayIndex` 的通知。
    case openReminder(dayIndex: Int)
    /// 手表点「已开始」。`dayIndex` 来自通知载荷；点了正文而没走通知时为 nil。
    case watchStart(dayIndex: Int?)
    /// 手表点「重新开始」。`sessionId` 是**手表看到的那一个**，
    /// 用来分辨这条意图是不是已经处理过了——丢弃会话是不可逆的，必须能判重。
    case watchRestart(dayIndex: Int, sessionId: UUID)
}

public enum SessionLaunchBlock: String, Codable, Equatable, Sendable {
    /// 计划里没有这一天，或者那天是休息日。
    case unknownDay
    /// 要放弃的那个不是当前会话（含「什么都没有」）——这条意图之前已经生效过。
    case staleRestart
}

public enum SessionLaunch: Equatable, Sendable {
    /// 内存里那个就是它，什么都不要做。
    case open(UUID)
    case resume(WorkoutCheckpoint)
    /// `planDate` 不在这里算：裁决器只决定走哪条路，日历锚点由调用方按
    /// `PlanCalendar.occurrence` 取（新建用 `now`，续练用 `checkpoint.startedAt`）。
    case create(dayIndex: Int, origin: SessionOrigin)
    case abandonAndCreate(abandon: UUID, dayIndex: Int, origin: SessionOrigin)
    case blocked(SessionLaunchBlock)
}

/// 会话的唯一入口。
///
/// 同一时刻只能有一次训练在进行，但代码里能「开始训练」的地方有四个
/// （今日页、短版、点通知、手表），它们原来各自 `UUID()` 新建，谁也不问
/// 「已经有一次在进行了」。点一条通知就把正在练的会话换掉、断点被覆盖，
/// 就是这么来的。
///
/// 规则按「内存会话优先于落盘断点」组织：`active` 存在时不去看 `stored`，
/// 因为内存永远比磁盘新（每次保存都双写），而「断点比内存新」这种状态不存在。
public enum SessionLaunchResolver {
    public static func resolve(
        intent: SessionIntent,
        active: ActiveSession?,
        stored: WorkoutCheckpoint?,
        plan: WorkoutPlan,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> SessionLaunch {
        // 「今天的」不能只看 dayIndex 相等：App 在后台挂了一夜，
        // active 的 dayIndex 还是昨天那个数字，但日历已经翻页了。
        let activeIsToday = active.map { calendar.isDate($0.startedAt, inSameDayAs: now) } ?? false
        let resumable = resumableCheckpoint(stored, plan: plan, now: now, calendar: calendar)

        switch intent {
        case .startToday:
            if let active, activeIsToday { return .open(active.id) }
            guard let occurrence = PlanCalendar.occurrence(on: now, in: plan, calendar: calendar) else {
                return .blocked(.unknownDay)
            }
            return .create(dayIndex: occurrence.dayIndex, origin: .phone)

        case let .openReminder(dayIndex):
            // 有今天的会话在进行时，无论通知说的是哪一天都认当前这个：
            // 通知可能是昨天没清掉的，用它去新建等于把今天的进度丢掉。
            if let active, activeIsToday { return .open(active.id) }
            guard isTrainingDay(dayIndex, in: plan) else { return .blocked(.unknownDay) }
            if let resumable, resumable.dayIndex == dayIndex { return .resume(resumable) }
            return .create(dayIndex: dayIndex, origin: .phone)

        case let .watchStart(dayIndex):
            // 手表点「开始」不是「再开一次」，是「我要练」——有在进行的就续上。
            if let active, activeIsToday { return .open(active.id) }
            if let dayIndex, !isTrainingDay(dayIndex, in: plan) { return .blocked(.unknownDay) }
            if let resumable { return .resume(resumable) }
            if let dayIndex { return .create(dayIndex: dayIndex, origin: .watch) }
            guard let occurrence = PlanCalendar.occurrence(on: now, in: plan, calendar: calendar) else {
                return .blocked(.unknownDay)
            }
            return .create(dayIndex: occurrence.dayIndex, origin: .watch)

        case let .watchRestart(dayIndex, sessionId):
            guard isTrainingDay(dayIndex, in: plan) else { return .blocked(.unknownDay) }
            if let active {
                // 只放弃「手表看到的那个」。不是它，说明这条意图已经生效过一次，
                // 第二次到达时若照样放弃，会把刚建好的新会话也丢掉。
                return active.id == sessionId
                    ? .abandonAndCreate(abandon: sessionId, dayIndex: dayIndex, origin: .watch)
                    : .blocked(.staleRestart)
            }
            if let stored, stored.sessionId == sessionId {
                return .abandonAndCreate(abandon: sessionId, dayIndex: dayIndex, origin: .watch)
            }
            return .blocked(.staleRestart)
        }
    }

    private static func resumableCheckpoint(
        _ checkpoint: WorkoutCheckpoint?,
        plan: WorkoutPlan,
        now: Date,
        calendar: Calendar
    ) -> WorkoutCheckpoint? {
        guard let checkpoint else { return nil }
        let validation = CheckpointValidator.validate(
            checkpoint,
            currentPlanRevision: plan.revision,
            now: now,
            calendar: calendar
        )
        return validation == .resumable ? checkpoint : nil
    }

    private static func isTrainingDay(_ dayIndex: Int, in plan: WorkoutPlan) -> Bool {
        plan.days.contains { $0.dayIndex == dayIndex && !$0.isRestDay }
    }
}

/// 「重新开始」的等待态。
///
/// 丢弃会话必须由 iPhone 裁决，手表只能等新上下文。等待期间不能记组——
/// 日志的 `sessionId` 还是旧的，记了会写进正要放弃的那个会话。
///
/// 放 Core 是为了可测：超时判定是逻辑，不是动画。
public enum RestartWaitState: Equatable, Sendable {
    case idle
    case waiting(startedAt: Date)
    case failed

    public static let timeout: TimeInterval = 8

    /// 到了超时点还没等到新上下文。
    public func hasTimedOut(at now: Date) -> Bool {
        guard case let .waiting(startedAt) = self else { return false }
        return now.timeIntervalSince(startedAt) >= Self.timeout
    }
}
