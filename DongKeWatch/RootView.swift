import SwiftUI
import DongKeCore

enum WatchRoute: Hashable {
    case workout(sessionId: UUID)
}

struct WatchRootView: View {
    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            WatchHomeView()
                .navigationDestination(for: WatchRoute.self) { route in
                    switch route {
                    case let .workout(sessionId):
                        WatchWorkoutPlaceholderView(sessionId: sessionId)
                    }
                }
        }
    }
}

private struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("动刻")
                .font(.headline)
            Text("请在 iPhone 上查看今天的训练")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct WatchWorkoutPlaceholderView: View {
    let sessionId: UUID

    var body: some View {
        Text("训练页建设中")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
