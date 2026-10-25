import SwiftUI
import SwiftData
import DongKeCore
import os

private let launchLog = Logger(subsystem: "app.dongke.ios", category: "voice")

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
        _planStore = State(initialValue: PlanStore(context: container.mainContext))

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

        launchLog.notice(
            "launch voice=\(VoiceService.voiceName, privacy: .public) enhanced=\(VoiceService.isEnhancedVoice, privacy: .public) enabled=\(VoiceService.isEnabledByUser, privacy: .public) build=\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?", privacy: .public)"
        )
    }

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
