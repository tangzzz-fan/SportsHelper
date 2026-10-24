import SwiftUI
import DongKeCore

extension BriefConfirmView {
    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("先对一下，再生成")
                .font(Typography.detailTitle)
            Text("这次只改本次生成，不会动你的档案；伤病限制始终保留。")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if brief.isVague {
                Text("没听出具体安排，下面按你的档案兜底，可以直接改。")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if brief.sentence.isEmpty == false {
                Text("「\(brief.sentence)」")
                    .font(Typography.meta)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var constraintCard: some View {
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

    var weekdaySection: some View {
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
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    var minutesSection: some View {
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

    var equipmentSection: some View {
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

    var goalSection: some View {
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

    var unparsedCard: some View {
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

    var footer: some View {
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

    var primaryButton: some View {
        Button {
            onConfirm(editedBrief)
        } label: {
            Text("按这个生成")
                .font(Typography.buttonLabel)
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

    var secondaryButton: some View {
        Button(action: onCancel) {
            Text("改一下描述")
                .font(Typography.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(A11y.Import.briefCancel)
    }

    func section<Content: View>(
        _ title: String,
        field: PlanBriefField,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.cardTitle)
                Text(sourceText(for: field))
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    func readOnlySection(_ title: String, field: PlanBriefField, values: [String]) -> some View {
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

    func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
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
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
