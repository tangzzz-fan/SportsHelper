import SwiftUI
import SwiftData
import DongKeCore
import os

private let launchLog = Logger(subsystem: "app.dongke.ios", category: "voice")

#if DEBUG
/// `DongKeApp.init` 的第一行时刻。用来量「进程起来到首帧画出内容」有多久。
/// 启动图什么时候消失只取决于这个时间，跟 launch screen 的配置无关。
nonisolated(unsafe) var dkInitTick: TimeInterval = 0
#endif

@main
struct DongKeApp: App {
    private let container: ModelContainer
    @State private var store: SessionStore
    @State private var setLogStore: SetLogStore
    @State private var profileStore: ProfileStore
    @State private var planStore: PlanStore
    @State private var userExerciseStore: UserExerciseStore
    @State private var aiSettings = AISettingsStore.shared

    init() {
        #if DEBUG
        dkInitTick = ProcessInfo.processInfo.systemUptime
        #endif
        let configuration = ModelConfiguration()
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SessionEntity.self, SetLogEntity.self, ProfileEntity.self,
                PlanEntity.self, UserExerciseEntity.self,
                configurations: configuration
            )
        } catch {
            container = try! ModelContainer(
                for: SessionEntity.self, SetLogEntity.self, ProfileEntity.self,
                PlanEntity.self, UserExerciseEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        self.container = container
        _store = State(initialValue: SessionStore(context: container.mainContext))
        _setLogStore = State(initialValue: SetLogStore(context: container.mainContext))
        let profiles = ProfileStore(context: container.mainContext)
        _profileStore = State(initialValue: profiles)
        let plans = PlanStore(context: container.mainContext)
        _planStore = State(initialValue: plans)

        #if DEBUG
        // 截图与预览用：在 body 之前就把演示档案写进库。
        // 放在视图的 .task 里会晚一帧 —— 第一帧仍然是 onboarding，
        // `DK_PREVIEW` 指定的页面要等重算后才出现，截图很容易抓到前那一帧。
        if ProcessInfo.processInfo.environment["DK_SEED_DEMO"] == "1",
           profiles.profile == nil {
            let (demoProfile, demoPlan) = Self.demoSeed()
            profiles.save(demoProfile)
            plans.save(demoPlan)
        }
        #endif

        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_COMPLETE_ONBOARDING"] == "1", !profiles.hasOnboarded {
            profiles.save(OnboardingDraft().completedProfile(now: Date()))
        }
        if let injuries = ProcessInfo.processInfo.environment["DK_PROFILE_INJURIES"], injuries.isEmpty == false {
            var profile = profiles.profile ?? OnboardingDraft().completedProfile(now: Date())
            profile.injuries = injuries
            profiles.save(profile)
        }
        #endif

        let userStore = UserExerciseStore(context: container.mainContext)
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_SEED_USER_EXERCISE"] == "1", userStore.all.isEmpty {
            userStore.add(UserExercise(
                name: "农夫行走",
                group: .core,
                equipment: .dumbbell,
                isStatic: true,
                defaultSets: 3,
                defaultValue: 40,
                restSec: 60
            ))
        }
        #endif
        _userExerciseStore = State(initialValue: userStore)

        // 这行会读 `VoicePicker.bestChinese()`，也就是枚举 AVSpeechSynthesisVoice。
        // 冷启动时那一步要加载系统音色清单，几百毫秒起步，放在 init 里会直接把
        // 首帧推后——表现就是启动图停留很久才淡出。日志晚一个 runloop 再打不值钱。
        Task { @MainActor in
            launchLog.notice(
                "launch voice=\(VoiceService.voiceName, privacy: .public) enhanced=\(VoiceService.isEnhancedVoice, privacy: .public) enabled=\(VoiceService.isEnabledByUser, privacy: .public) build=\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?", privacy: .public)"
            )
        }
    }

    #if DEBUG
    /// 截图用的固定演示档案。
    ///
    /// 计划从 `SampleData.plan` 派生（深蹲/弓步蹲/臀桥那套），不走 `PlanGenerator`——
    /// 截图要每次都是同一份，不能随日期漂。但样例本身只有两个训练日，
    /// 计划页会显得「周一到周五全在休息」，所以在这里铺成完整一周：
    /// 今天 / 后天 / 大后天各一次，其余补休息日。
    private static func demoSeed() -> (UserProfile, WorkoutPlan) {
        var profile = UserProfile(
            heightCm: 178,
            weightKg: 72,
            age: 32,
            sex: .male,
            goal: .loseFat,
            level: .beginner,
            availableWeekdays: [.sunday, .saturday, .thursday],
            sessionMinutes: 30,
            equipment: [.bodyweight],
            injuries: "",
            reminderEnabled: false
        )
        profile.onboardedAt = Date()

        let source = SampleData.plan
        let today = SampleData.weekday(for: Date())
        let templates: [(PlanDay, String)] = [
            (source.days[0], "下肢力量"),
            (source.days[1], "上肢与核心"),
            (source.days[0], "下肢力量"),
        ]
        let offsets = [0, 2, 4]

        var days: [PlanDay] = []
        for (index, entry) in templates.enumerated() {
            days.append(
                restamped(
                    entry.0,
                    dayIndex: index,
                    weekday: shifted(today, by: offsets[index]),
                    title: entry.1
                )
            )
        }
        for offset in 1...6 where offsets.contains(offset) == false {
            days.append(
                PlanDay(
                    dayIndex: 3 + offset,
                    weekday: shifted(today, by: offset),
                    isRestDay: true,
                    title: "休息",
                    scheduledTime: nil,
                    estimatedMinutes: 0,
                    blocks: []
                )
            )
        }
        days.sort { $0.weekday.rawValue < $1.weekday.rawValue }

        var plan = source
        plan.days = days
        plan.meta.daysPerWeek = 3
        return (profile, plan)
    }

    /// 复制一天的内容，同时把 dayIndex / weekday / 标题换掉，
    /// 并把 blockId、itemId 重新编号——同一份处方在计划里出现两次时 id 不能撞。
    private static func restamped(
        _ source: PlanDay,
        dayIndex: Int,
        weekday: Weekday,
        title: String
    ) -> PlanDay {
        var copy = source
        copy.dayIndex = dayIndex
        copy.weekday = weekday
        copy.title = title
        copy.scheduledTime = TimeOfDay(hour: 20, minute: 30)
        copy.blocks = source.blocks.enumerated().map { blockIndex, block in
            var newBlock = block
            newBlock.blockId = "b\(dayIndex)-\(blockIndex)"
            newBlock.title = title
            newBlock.items = block.items.enumerated().map { itemIndex, item in
                var newItem = item
                newItem.itemId = "d\(dayIndex)-\(blockIndex)-\(itemIndex)"
                return newItem
            }
            return newBlock
        }
        return copy
    }

    private static func shifted(_ weekday: Weekday, by days: Int) -> Weekday {
        let all = Weekday.allCases
        guard let index = all.firstIndex(of: weekday) else { return weekday }
        return all[(index + days) % all.count]
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(setLogStore)
                .environment(profileStore)
                .environment(planStore)
                .environment(userExerciseStore)
                .environment(aiSettings)
                .environment(NotificationService.shared)
        }
        .modelContainer(container)
    }
}
