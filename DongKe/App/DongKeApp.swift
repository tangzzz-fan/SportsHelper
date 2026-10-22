import SwiftUI
import SwiftData

@main
struct DongKeApp: App {
    private let container: ModelContainer
    @State private var store: SessionStore

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: SessionEntity.self)
        } catch {
            container = try! ModelContainer(
                for: SessionEntity.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        self.container = container
        _store = State(initialValue: SessionStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(store)
                .environment(NotificationService.shared)
        }
        .modelContainer(container)
    }
}
