import SwiftUI
import SwiftData
import DongKeCore

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
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SessionEntity.self, SetLogEntity.self, ProfileEntity.self,
                PlanEntity.self, UserExerciseEntity.self
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
        _profileStore = State(initialValue: ProfileStore(context: container.mainContext))
        _planStore = State(initialValue: PlanStore(context: container.mainContext))

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
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
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
