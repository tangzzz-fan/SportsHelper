import SwiftUI
import DongKeCore

struct UserExerciseDetailView: View {
    let exercise: UserExercise

    @Environment(\.colorScheme) private var colorScheme
    @Environment(UserExerciseStore.self) private var userExercises
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 8) {
                    ExerciseFigureView(
                        catalogId: exercise.id,
                        figureSize: CGSize(width: 190, height: 220)
                    )
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .semibold))
                    Text("我的动作 · \(exercise.group.title)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("默认剂量")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(exercise.defaultSets) 组 × \(exercise.defaultValue) \(exercise.doseUnit)，组间休息 \(exercise.restSec) 秒")
                        .font(.system(size: 16, weight: .medium))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(radius: Theme.Radius.card)
                }

                Text("这个动作不在内置动作库里，图示用通用示意代替，要点需要你自己把握。导入计划时遇到同名动作会直接指向它。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    userExercises.remove(id: exercise.id)
                    dismiss()
                } label: {
                    Text("从我的动作里删掉")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PressableGlassStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
