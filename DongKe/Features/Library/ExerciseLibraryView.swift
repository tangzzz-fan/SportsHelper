import SwiftUI
import DongKeCore

struct ExerciseLibraryView: View {
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(UserExerciseStore.self) private var userExercises
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
        } else if let previewMine {
            NavigationStack {
                UserExerciseDetailView(exercise: previewMine)
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

    private var previewMine: UserExercise? {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["DK_PREVIEW"] == "myexercise" else { return nil }
        return userExercises.all.first
        #else
        return nil
        #endif
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

                    if userExercises.all.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("我的动作")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(userExercises.all.enumerated()), id: \.element.id) { index, exercise in
                                    NavigationLink {
                                        UserExerciseDetailView(exercise: exercise)
                                    } label: {
                                        userRow(exercise)
                                    }
                                    .buttonStyle(.plain)

                                    if index < userExercises.all.count - 1 {
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
                    .font(Typography.rowTitle)
                    .foregroundStyle(.primary)
                Text(entry.tagText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: Icons.disclosure)
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func userRow(_ exercise: UserExercise) -> some View {
        HStack(spacing: 12) {
            ExerciseFigureView(
                catalogId: exercise.id,
                figureSize: CGSize(width: 44, height: 52),
                showsHalo: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(Typography.rowTitle)
                    .foregroundStyle(.primary)
                Text("\(exercise.defaultSets) 组 × \(exercise.defaultValue) \(exercise.doseUnit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: Icons.disclosure)
                .font(Typography.micro)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
