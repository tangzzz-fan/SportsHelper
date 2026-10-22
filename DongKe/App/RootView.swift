import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("深蹲")
                .font(.title2.weight(.semibold))
            ExerciseFigureView(catalogId: "squat")
            Text("12 次 × 4 组")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
