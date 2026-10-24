import SwiftUI
import DongKeCore

struct BriefConfirmView: View {
    let brief: PlanBrief
    let profile: UserProfile
    var onCancel: () -> Void
    var onConfirm: (PlanBrief) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var weekdays: [Weekday]
    @State private var minutes: Int
    @State private var equipment: [Equipment]
    @State private var goal: PlanGoal

    private let minuteOptions = [20, 30, 45, 60]

    init(
        brief: PlanBrief,
        profile: UserProfile,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (PlanBrief) -> Void
    ) {
        self.brief = brief
        self.profile = profile
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        let effective = brief.resolved(against: profile)
        _weekdays = State(initialValue: effective.weekdays)
        _minutes = State(initialValue: effective.sessionMinutes)
        _equipment = State(initialValue: effective.equipment)
        _goal = State(initialValue: effective.goal)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if constraintText.isEmpty == false {
                        constraintCard
                    }
                    weekdaySection
                    minutesSection
                    equipmentSection
                    goalSection

                    if brief.focus.isEmpty == false {
                        readOnlySection("重点部位", field: .focus, values: brief.focus)
                    }
                    if brief.unparsed.isEmpty == false {
                        unparsedCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("我理解为")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", action: onCancel)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("先对一下，再生成")
                .font(Typography.detailTitle)
            Text("这次只改本次生成，不会动你的档案；伤病限制始终保留。")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if brief.sentence.isEmpty == false {
                Text("「\(brief.sentence)」")
                    .font(Typography.meta)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var constraintCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: Icons.mistake)
                .font(Typography.meta.weight(.semibold))
                .foregroundStyle(Theme.danger(for: colorScheme))
            Text(constraintText)
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.card)
    }

    private var weekdaySection: some View {
        section("每周哪天", field: .weekdays) {
            LazyVGrid(columns: chips, alignment: .leading, spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    chip(day.chineseName, selected: weekdays.contains(day)) {
                        toggle(day)
                    }
                }
            }
            Text("共 \(weekdays.count) 天")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
        }
    }

    private var minutesSection: some View {
        section("每次多久", field: .sessionMinutes) {
            LazyVGrid(columns: chips, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { value in
                    chip("\(value) 分钟", selected: minutes == value) {
                        minutes = value
                    }
                }
            }
        }
    }

    private var equipmentSection: some View {
        section("器械", field: .equipment) {
            LazyVGrid(columns: chips, alignment: .leading, spacing: 8) {
                ForEach(Equipment.allCases, id: \.self) { item in
                    chip(item.chineseName, selected: equipment.contains(item)) {
                        toggle(item)
                    }
                }
            }
        }
    }

    private var goalSection: some View {
        section("目标", field: .goal) {
            LazyVGrid(columns: chips, alignment: .leading, spacing: 8) {
                ForEach(PlanGoal.allCases, id: \.self) { item in
                    chip(item.chineseName, selected: goal == item) {
                        goal = item
                    }
                }
            }
        }
    }

    private var unparsedCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("没完全听懂")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
            ForEach(brief.unparsed, id: \.self) { item in
                Text("· \(item)")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.card)
    }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 6) {
                    primaryButton
                    secondaryButton
                }
            } else {
                HStack(spacing: 12) {
                    secondaryButton
                    primaryButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemGroupedBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var primaryButton: some View {
        Button {
            onConfirm(editedBrief)
        } label: {
            Text("按这个生成")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PressableGlassStyle())
        .foregroundStyle(Theme.callToActionInk(for: colorScheme))
        .background(
            Theme.accent(for: colorScheme),
            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        )
        .accessibilityIdentifier(A11y.Import.briefConfirm)
    }

    private var secondaryButton: some View {
        Button(action: onCancel) {
            Text("改一下描述")
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(A11y.Import.briefCancel)
    }

    private func section<Content: View>(
        _ title: String,
        field: PlanBriefField,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Typography.cardTitle)
                Text(sourceText(for: field))
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func readOnlySection(_ title: String, field: PlanBriefField, values: [String]) -> some View {
        section(title, field: field) {
            LazyVGrid(columns: chips, alignment: .leading, spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.meta.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.callToActionInk(for: colorScheme) : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 40)
                .padding(.horizontal, 6)
                .background(
                    selected ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.06),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var chips: [GridItem] {
        [GridItem(.adaptive(minimum: 72), spacing: 8)]
    }

    private var options: [Int] {
        Array(Set(minuteOptions + [minutes])).sorted()
    }

    private var injuries: String {
        profile.injuries.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var constraintText: String {
        var lines: [String] = []
        if injuries.isEmpty == false {
            lines.append("档案伤病：\(injuries)")
        }
        if brief.avoid.isEmpty == false {
            lines.append("这次避开：\(brief.avoid.joined(separator: "、"))")
        }
        return lines.joined(separator: "；")
    }

    private var editedBrief: PlanBrief {
        var copy = brief
        copy.weekdays = weekdays.sorted { $0.rawValue < $1.rawValue }
        copy.daysPerWeek = nil
        copy.sessionMinutes = minutes
        copy.equipment = equipment
        copy.goal = goal
        return copy
    }

    private func toggle(_ day: Weekday) {
        if let index = weekdays.firstIndex(of: day) {
            guard weekdays.count > 1 else { return }
            weekdays.remove(at: index)
        } else {
            weekdays.append(day)
            weekdays.sort { $0.rawValue < $1.rawValue }
        }
    }

    private func toggle(_ item: Equipment) {
        if let index = equipment.firstIndex(of: item) {
            guard equipment.count > 1 else { return }
            equipment.remove(at: index)
        } else {
            equipment.append(item)
        }
    }

    private func sourceText(for field: PlanBriefField) -> String {
        brief.overriddenFields.contains(field) ? "你说的" : "沿用档案"
    }
}
