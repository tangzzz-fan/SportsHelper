import SwiftUI
import DongKeCore

struct ExerciseLibraryView: View {
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var previewDetail = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        #if DEBUG
        _previewDetail = State(initialValue: ProcessInfo.processInfo.environment["DK_PREVIEW"] == "detail")
        #endif
    }

    private var grouped: [(group: ExerciseGroup, entries: [ExerciseEntry])] {
        ExerciseLibrary.grouped().filter { !$0.entries.isEmpty }
    }

    var body: some View {
        if previewDetail, let entry = ExerciseLibrary.entry(for: "squat") {
            NavigationStack {
                ExerciseDetailView(entry: entry)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭", action: onClose)
                                .foregroundStyle(Theme.accent(for: colorScheme))
                        }
                    }
            }
        } else {
            libraryBody
        }
    }

    private var libraryBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(grouped, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.group.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                    NavigationLink {
                                        ExerciseDetailView(entry: entry)
                                    } label: {
                                        row(entry)
                                    }
                                    .buttonStyle(.plain)

                                    if index < section.entries.count - 1 {
                                        Divider()
                                            .overlay(Color.primary.opacity(0.06))
                                            .padding(.leading, 78)
                                    }
                                }
                            }
                            .glassSurface(radius: Theme.Radius.glassCard)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("动作库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭", action: onClose)
                        .foregroundStyle(Theme.accent(for: colorScheme))
                }
            }
        }
    }

    private func row(_ entry: ExerciseEntry) -> some View {
        HStack(spacing: 12) {
            ExerciseFigureView(
                catalogId: entry.id,
                figureSize: CGSize(width: 44, height: 52),
                showsHalo: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Text(entry.tagText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

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
                        .font(.system(size: 24, weight: .semibold))
                    Text(entry.tagText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if FigureLibrary.bundled.figure(for: entry.id).frames.count > 1 {
                        Text("轻点图示可播放动作循环")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                block(title: "要点", symbol: "checkmark.circle", lines: entry.cues)
                block(title: "常见错误", symbol: "exclamationmark.triangle", lines: entry.mistakes)

                VStack(alignment: .leading, spacing: 8) {
                    Text("做不动时换成")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text(entry.regressionName)
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        if let id = entry.regressionId, let target = ExerciseLibrary.entry(for: id) {
                            NavigationLink {
                                ExerciseDetailView(entry: target)
                            } label: {
                                HStack(spacing: 2) {
                                    Text("看这个")
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text(line)
                            .font(.system(size: 15))
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
