import SwiftUI
import DongKeCore

struct OnboardingView: View {
    var onFinish: (UserProfile) -> Void

    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep
    @Environment(\.colorScheme) private var colorScheme

    init(initialStep: OnboardingStep = .basics, onFinish: @escaping (UserProfile) -> Void) {
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        ZStack(alignment: .top) {
            background

            VStack(alignment: .leading, spacing: 0) {
                progressDots
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Text(step.title)
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                Text(step.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                ScrollView {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    private var background: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.8, y: 0.12),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.12))
                    .frame(height: 4)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .basics:
            VStack(spacing: 12) {
                stepperCard("身高", value: "\(draft.profile.heightCm) cm") {
                    draft.profile.heightCm = clamp(draft.profile.heightCm - 1, 120, 230)
                } onIncrease: {
                    draft.profile.heightCm = clamp(draft.profile.heightCm + 1, 120, 230)
                }
                stepperCard("体重", value: String(format: "%.0f kg", draft.profile.weightKg)) {
                    draft.profile.weightKg = clamp(draft.profile.weightKg - 1, 30, 250)
                } onIncrease: {
                    draft.profile.weightKg = clamp(draft.profile.weightKg + 1, 30, 250)
                }
                stepperCard("年龄", value: "\(draft.profile.age) 岁") {
                    draft.profile.age = clamp(draft.profile.age - 1, 14, 90)
                } onIncrease: {
                    draft.profile.age = clamp(draft.profile.age + 1, 14, 90)
                }
                chipRow(title: "性别", options: Sex.allCases.map { ($0, $0.chineseName) }, isSelected: { draft.profile.sex == $0 }) { sex in
                    draft.profile.sex = sex
                }
            }
        case .goal:
            chipGrid(title: "目标", options: goalOptions, isSelected: { draft.profile.goal == $0 }) { goal in
                draft.profile.goal = goal
            }
        case .level:
            VStack(spacing: 16) {
                chipGrid(title: "当前水平", options: levelOptions, isSelected: { draft.profile.level == $0 }) { level in
                    draft.profile.level = level
                }
                chipRow(
                    title: "每次时长",
                    options: OnboardingDraft.sessionOptions.map { ($0, "\($0) 分钟") },
                    isSelected: { draft.profile.sessionMinutes == $0 }
                ) { minutes in
                    draft.profile.sessionMinutes = minutes
                }
            }
        case .availability:
            VStack(spacing: 16) {
                chipRow(
                    title: "能练的日子",
                    options: Weekday.allCases.map { ($0, $0.chineseName) },
                    isSelected: { draft.profile.availableWeekdays.contains($0) }
                ) { weekday in
                    draft.toggleWeekday(weekday)
                }
                chipRow(
                    title: "手边有什么",
                    options: Equipment.allCases.map { ($0, $0.chineseName) },
                    isSelected: { draft.profile.equipment.contains($0) }
                ) { item in
                    draft.toggleEquipment(item)
                }
            }
        case .healthAndReminder:
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("伤病或要避开的动作")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { draft.profile.injuries },
                        set: { draft.profile.injuries = $0 }
                    ))
                    .frame(height: 88)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .glassSurface(radius: Theme.Radius.card)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("训练提醒")
                            .font(.system(size: 16, weight: .medium))
                        Text("按训练日提前 5 分钟")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { draft.profile.reminderEnabled },
                        set: { draft.profile.reminderEnabled = $0 }
                    ))
                    .labelsHidden()
                    .tint(Theme.accent(for: colorScheme))
                }
                .padding(16)
                .glassSurface(radius: Theme.Radius.card)

                HStack {
                    Text("提醒时间")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                Calendar.current.date(
                                    bySettingHour: draft.profile.reminderTime.hour,
                                    minute: draft.profile.reminderTime.minute,
                                    second: 0,
                                    of: Date()
                                ) ?? Date()
                            },
                            set: { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                draft.profile.reminderTime = TimeOfDay(
                                    hour: components.hour ?? 20,
                                    minute: components.minute ?? 30
                                )
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                .padding(16)
                .glassSurface(radius: Theme.Radius.card)
                .opacity(draft.profile.reminderEnabled ? 1 : 0.45)
                .disabled(!draft.profile.reminderEnabled)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                Text(step == .healthAndReminder ? "完成" : "下一步")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                draft.canAdvance(from: step) ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.18),
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .disabled(!draft.canAdvance(from: step))

            Button(step == .basics ? "跳过，用默认值" : "返回") {
                if step == .basics {
                    finish(with: draft.profile)
                } else {
                    back()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    private var goalOptions: [(PlanGoal, String)] {
        PlanGoal.allCases.map { ($0, $0.chineseName) }
    }

    private var levelOptions: [(TrainingLevel, String)] {
        TrainingLevel.allCases.map { ($0, $0.chineseName) }
    }

    private func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            finish(with: draft.profile)
        }
    }

    private func back() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func finish(with profile: UserProfile) {
        onFinish(draft.completedProfile(now: Date()))
    }

    private func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }

    private func stepperCard(
        _ title: String,
        value: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            HStack(spacing: 14) {
                Button(action: onDecrease) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                Text(value)
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 66)
                Button(action: onIncrease) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
            }
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
    }

    private func chipRow<T: Hashable>(
        title: String,
        options: [(T, String)],
        isSelected: @escaping (T) -> Bool,
        onTap: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Chip(label: option.1, selected: isSelected(option.0)) {
                        onTap(option.0)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.card)
    }

    private func chipGrid<T: Hashable>(
        title: String,
        options: [(T, String)],
        isSelected: @escaping (T) -> Bool,
        onTap: @escaping (T) -> Void
    ) -> some View {
        chipRow(title: title, options: options, isSelected: isSelected, onTap: onTap)
    }
}

struct Chip: View {
    let label: String
    let selected: Bool
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.accent(for: colorScheme) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    selected ? Theme.halo(for: colorScheme) : Color.primary.opacity(0.05),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            selected ? Theme.accent(for: colorScheme).opacity(0.45) : Color.clear,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(PressableGlassStyle())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: proposal.width ?? maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
