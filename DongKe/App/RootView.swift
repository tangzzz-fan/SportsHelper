import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            ExerciseFigureView(catalogId: "squat", figureSize: CGSize(width: 320, height: 380))
                .opacity(0.12)
                .offset(y: -40)

            VStack(spacing: 16) {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("下肢力量")
                        .font(.title3.weight(.semibold))
                    Text("4 个动作 · 约 30 分钟 · 20:30")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ExerciseFigureView(catalogId: "squat", figureSize: CGSize(width: 150, height: 176))
                        .frame(maxWidth: .infinity)

                    Button {
                    } label: {
                        Text("开始训练")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .foregroundStyle(.white)
                    .background(
                        Theme.accent(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.52), .white.opacity(0.06)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(radius: Theme.Radius.glassCard)

                HStack(spacing: 12) {
                    Text("今日").font(.footnote.weight(.semibold))
                    Text("计划").font(.footnote)
                    Text("记录").font(.footnote)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .glassSurface(radius: Theme.Radius.glassIsland)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
    }
}
