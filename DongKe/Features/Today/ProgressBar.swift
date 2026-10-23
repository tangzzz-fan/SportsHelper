import SwiftUI

struct ProgressBar: View {
    var progress: Double
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SessionStore.self) private var store

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Theme.accent(for: colorScheme))
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 4)
    }
}
