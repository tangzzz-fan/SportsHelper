import SwiftUI
import DongKeCore

enum WatchRoute: Hashable {
    case workout(sessionId: UUID)
}

struct WatchRootView: View {
    @State private var path: [WatchRoute] = []
    @State private var model = WatchContextModel.shared

    var body: some View {
        NavigationStack(path: $path) {
            WatchHomeView(context: model.context)
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
    let context: WatchContext?

    var body: some View {
        VStack(spacing: 6) {
            if let context {
                Text(context.dayTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let step = context.currentStep,
                   case let .set(prescriptionId, setIndex, target, _) = step,
                   let exercise = context.exercise(for: prescriptionId) {
                    Text(exercise.name)
                        .font(.footnote)
                    Text("第 \(setIndex) 组，共 \(exercise.setCount) 组")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(target.doseText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("休息或组间调整")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("动刻")
                    .font(.headline)
                Text("请在 iPhone 上开始训练")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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
