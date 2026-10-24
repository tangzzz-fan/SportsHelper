import SwiftUI
import DongKeCore

struct QuickAIPlanSheet: View {
    var onSaved: (WorkoutPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UserExerciseStore.self) private var userExercises
    @State private var sentence = ""
    @State private var review: Review?
    @State private var failure: String?
    private let memo = AliasMemoStore()

    private struct Review: Identifiable {
        let id = UUID()
        let draft: ParsedPlanDraft
        let plan: WorkoutPlan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AIGenerateCard(
                        sentence: $sentence,
                        memory: memo.load(),
                        exercises: userExercises.catalog
                    ) { draft in
                        guard let plan = draft.plan else {
                            failure = draft.issues.first?.message ?? "生成的内容没能识别成计划，可以重试或改用粘贴导入。"
                            return
                        }
                        failure = nil
                        review = Review(draft: draft, plan: plan.markingSource(.ai))
                    }

                    if let failure {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }

                    Text("生成后先在校对页确认动作与剂量，保存才会替换当前计划。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("让 AI 排计划")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { review != nil },
                set: { if !$0 { review = nil } }
            )) {
                if let review {
                    PlanReviewView(draft: review.draft, plan: review.plan) { saved in
                        onSaved(saved)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
