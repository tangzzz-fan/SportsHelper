import SwiftUI
import DongKeCore

struct ExerciseDetailView: View {
    let entry: ExerciseEntry

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    ExerciseFigureView(
                        catalogId: entry.id,
                        figureSize: CGSize(width: 190, height: 220)
                    )
                    Text(entry.name)
                        .font(Typography.detailTitle)
                    Text(entry.tagText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if FigureLibrary.bundled.hasArtwork(for: entry.id) {
                        if FigureLibrary.bundled.figure(for: entry.id).frames.count > 1 {
                            Text("轻点图示可播放动作循环")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("这个动作暂时没有示意图，按下面的要点做")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                block(title: "要点", symbol: Icons.cue, lines: entry.cues)
                block(title: "常见错误", symbol: Icons.mistake, lines: entry.mistakes)

                VStack(alignment: .leading, spacing: 8) {
                    Text("做不动时换成")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text(entry.regressionName)
                            .font(Typography.rowTitle)
                        Spacer()
                        if let id = entry.regressionId, let target = ExerciseLibrary.entry(for: id) {
                            NavigationLink {
                                ExerciseDetailView(entry: target)
                            } label: {
                                HStack(spacing: 2) {
                                    Text("看这个")
                                    Image(systemName: Icons.disclosure)
                                        .font(Typography.capsLabel)
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent(for: colorScheme))
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(radius: Theme.Radius.card)
                }

                Text("图示为开源素材库的动作示意，与个人体型、器械无关，动作幅度以无痛为限。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(title: String, symbol: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(Typography.meta.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .font(Typography.secondary.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        Text(line)
                            .font(Typography.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(radius: Theme.Radius.card)
        }
    }
}
