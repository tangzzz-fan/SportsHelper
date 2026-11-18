import SwiftUI
import DongKeCore

struct PlanAdjustView: View {
    let plan: WorkoutPlan
    let profile: UserProfile
    var onAdjusted: (UserProfile, WorkoutPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SetLogStore.self) private var setLogStore
    @Environment(PlanStore.self) private var planStore
    @State private var showReceipt = false
    @State private var goal: PlanGoal
    @State private var level: TrainingLevel
    @State private var minutes: Int
    @State private var showsConfirm = false

    private let minuteChoices = [15, 20, 30, 45, 60]

    init(plan: WorkoutPlan, profile: UserProfile, onAdjusted: @escaping (UserProfile, WorkoutPlan) -> Void) {
        self.plan = plan
        self.profile = profile
        self.onAdjusted = onAdjusted
        _goal = State(initialValue: profile.goal)
        _level = State(initialValue: profile.level)
        _minutes = State(initialValue: profile.sessionMinutes)
    }

    private var draftProfile: UserProfile {
        var copy = profile
        copy.goal = goal
        copy.level = level
        copy.sessionMinutes = minutes
        return copy
    }

    private var draftPlan: WorkoutPlan {
        PlanGenerator.makePlan(
            profile: draftProfile,
            variation: plan.revision + 1
        ).markingSource(.generated, revision: plan.revision + 1)
    }

    /// 首屏先把「带着记录回去问」摆出来：计划是外面给的，就该拿执行数据回去改。
    private var askFirstCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("带着记录回去问")
                .font(Typography.cardTitle)
            Text("把最近 4 周的执行情况复制给你的 AI 或教练，让他们按真实数据改这份计划。比在这里换一批动作准得多。")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showReceipt = true
            } label: {
                Text("复制训练回执")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11y.Plan.adjustReceipt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
        .sheet(isPresented: $showReceipt) {
            ReceiptSheet(text: receiptText)
        }
    }

    private var receiptText: String {
        let plan = planStore.plan ?? self.plan
        return TrainingReceiptBuilder.build(logs: setLogStore.recentLogs(limit: 600), plan: plan).text
    }

    private var changedIds: (added: [String], removed: [String]) {
        let old = workoutIds(in: plan)
        let new = workoutIds(in: draftPlan)
        let names = Dictionary(
            ExerciseLibrary.all.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let added = new.subtracting(old).compactMap { names[$0] }.sorted()
        let removed = old.subtracting(new).compactMap { names[$0] }.sorted()
        return (added, removed)
    }

    private func workoutIds(in plan: WorkoutPlan) -> Set<String> {
        Set(plan.days.filter { !$0.isRestDay }.flatMap { $0.blocks.flatMap { $0.items.map(\.catalogId) } })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    askFirstCard

                    Text("下面的选项是不联网时的兜底：换一批动作、改难度。加量减量不用你来发现——那件事交给记录和提案。")
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    section("目标") {
                        HStack(spacing: 8) {
                            ForEach(PlanGoal.selectable, id: \.self) { value in
                                chip(value.chineseName, on: goal == value) { goal = value }
                            }
                        }
                    }
                    section("难度") {
                        HStack(spacing: 8) {
                            ForEach(TrainingLevel.allCases, id: \.self) { value in
                                chip(value.chineseName, on: level == value) { level = value }
                            }
                        }
                    }
                    section("每次时长") {
                        HStack(spacing: 8) {
                            ForEach(minuteChoices, id: \.self) { value in
                                chip("\(value) 分", on: minutes == value) { minutes = value }
                            }
                        }
                    }

                    changePreview

                    Text("会替换掉当前这份计划，没有副本；已经练过的记录不受影响。改动写进档案，下次重新生成也沿用。第 \(plan.revision) 版 → 第 \(plan.revision + 1) 版。")
                        .font(Typography.capsLabel)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showsConfirm = true
                    } label: {
                        Text("生成第 \(plan.revision + 1) 版")
                            .font(Typography.buttonLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PressableGlassStyle())
                    .foregroundStyle(Theme.callToActionInk(for: colorScheme))
                    .background(
                        Theme.accent(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .accessibilityIdentifier(A11y.Plan.adjustApply)
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("调整计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .confirmationDialog(
                "会用新参数排一份计划，替换现在这份。已经练过的记录不受影响。",
                isPresented: $showsConfirm,
                titleVisibility: .visible
            ) {
                Button("换一版") {
                    onAdjusted(draftProfile, draftPlan)
                    dismiss()
                }
                .accessibilityIdentifier(A11y.Plan.adjustConfirm)
                Button("再想想", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var changePreview: some View {
        let changed = changedIds
        if changed.added.isEmpty && changed.removed.isEmpty {
            Text("按现在的设置重排，动作不会变。想换花样就把时长或难度调一档。")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(A11y.Plan.adjustPreview)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("动作会这样变")
                    .font(Typography.cardTitle)
                if changed.added.isEmpty == false {
                    Text("新进：\(changed.added.joined(separator: "、"))")
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if changed.removed.isEmpty == false {
                    Text("换下：\(changed.removed.joined(separator: "、"))")
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier(A11y.Plan.adjustPreview)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typography.rowTitle)
            content()
        }
    }

    private func chip(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Typography.secondary.weight(.medium))
                .foregroundStyle(on ? Color.white : Color.primary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    on ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.07),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressableGlassStyle())
    }
}
