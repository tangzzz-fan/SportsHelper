import SwiftUI
import DongKeCore


extension OnboardingView {
    @ViewBuilder
    var content: some View {
        switch step {
        case .basics:
            VStack(spacing: 12) {
                chipRow(
                    title: "字要大一点吗",
                    options: [(false, "标准"), (true, "大字")],
                    isSelected: { $0 == largeText.isEnabled }
                ) { wantsLarge in
                    largeText.isEnabled = wantsLarge
                }
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
                            .font(Typography.rowTitle)
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
                        .font(Typography.rowTitle)
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
}
