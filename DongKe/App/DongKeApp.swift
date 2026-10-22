import SwiftUI
import SwiftData

@main
struct DongKeApp: App {
    private let container: ModelContainer
    @State private var store: SessionStore
    @State private var profileStore: ProfileStore

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: SessionEntity.self, ProfileEntity.self)
        } catch {
            container = try! ModelContainer(
                for: SessionEntity.self, ProfileEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        self.container = container
        _store = State(initialValue: SessionStore(context: container.mainContext))
        _profileStore = State(initialValue: ProfileStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(store)
                .environment(profileStore)
                .environment(NotificationService.shared)
        }
        .modelContainer(container)
    }
}
