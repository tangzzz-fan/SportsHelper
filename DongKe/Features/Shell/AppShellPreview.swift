import Foundation

#if DEBUG
/// `DK_PREVIEW` 的截图与校对入口。
///
/// 单独一个文件是为了让 `AppShell` 别再往上涨——它已经贴着 500 行门禁了，
/// 而这块是纯调试代码，跟着发布版一起被 `#if DEBUG` 剥掉。
enum AppShellPreview {
    struct Configuration {
        var session: WorkoutSession?
        var tab: AppShell.Tab?
    }

    @MainActor
    static func make() -> Configuration? {
        let preview = ProcessInfo.processInfo.environment["DK_PREVIEW"] ?? ""
        guard !preview.isEmpty else { return nil }

        var dayIndex = SampleData.trainingDayIndex(for: Date())
        if ProcessInfo.processInfo.environment["DK_WORKOUT_LOAD"] == "1",
           let loadedDay = SampleData.plan.days.first(where: { day in
               day.blocks.flatMap(\.items).contains {
                   $0.load.type != .bodyweight && $0.load.value > 0
               }
           })?.dayIndex {
            // 负重动作不一定落在「今天」那一节，UI 测试要一个确定的起点。
            dayIndex = loadedDay
        }

        switch preview {
        case "workout", "swap":
            let active = WorkoutSession(plan: SampleData.plan, dayIndex: dayIndex)
            if ProcessInfo.processInfo.environment["DK_WORKOUT_LOAD"] == "1" {
                active.stepIndex = firstLoadedStepIndex(in: active) ?? active.stepIndex
            }
            if ProcessInfo.processInfo.environment["DK_SWAP_FIRST"] == "1",
               let entry = active.swapCandidates(available: [.bodyweight]).first {
                // 预览用：换掉第一个动作，用来校对换完之后那一页。
                active.swapCurrent(with: entry)
            }
            return Configuration(session: active, tab: nil)
        case "plan":
            return Configuration(session: nil, tab: .plan)
        case "history":
            return Configuration(session: nil, tab: .history)
        case "library", "import", "detail", "myexercise", "adjust":
            return Configuration(session: nil, tab: .plan)
        case "summary":
            let active = WorkoutSession(
                plan: SampleData.plan,
                dayIndex: dayIndex,
                startedAt: Date().addingTimeInterval(-28 * 60)
            )
            // 11/12 组：完成率 92%，其中有 1 组是降阶。
            // 只做 5 组的话总结页是 42%，商店截图里像练砸了。
            for _ in 0..<10 {
                active.completeSet()
                active.skipRest()
            }
            active.downgradeSet()
            active.skipRest()
            active.endWorkout()
            // 预览里没有日志库，破纪录算不出来；给一句固定文案，用来校对结束页的排版。
            active.narrative = "深蹲 10kg 做了 12 个，比上次多 2 个"
            return Configuration(session: active, tab: nil)
        case "rest":
            let active = WorkoutSession(plan: SampleData.plan, dayIndex: dayIndex)
            active.completeSet()
            // 预览里没有日志库，破纪录判定不会触发；给一张固定的庆祝文案，用来校对休息面板的排版。
            active.recordCelebration = "深蹲最高纪录 13 个"
            return Configuration(session: active, tab: nil)
        default:
            return nil
        }
    }

    /// UI 测试用：跳到第一个负重动作，省掉「先做几组自重」的点击。
    @MainActor
    private static func firstLoadedStepIndex(in session: WorkoutSession) -> Int? {
        let items = session.day?.blocks.flatMap(\.items) ?? []
        let loads = Dictionary(uniqueKeysWithValues: items.map { ($0.itemId, $0.load) })
        return session.script.firstIndex { step in
            guard case let .set(id, _, _, _) = step, let load = loads[id] else { return false }
            return load.type != .bodyweight && load.value > 0
        }
    }
}
#endif
