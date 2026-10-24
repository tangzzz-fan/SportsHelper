import SwiftUI
import DongKeCore

struct BriefConfirmView: View {
    let brief: PlanBrief
    let profile: UserProfile
    var onCancel: () -> Void
    var onConfirm: (PlanBrief) -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State var weekdays: [Weekday]
    @State var minutes: Int
    @State var equipment: [Equipment]
    @State var goal: PlanGoal

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

    var editedBrief: PlanBrief {
        var copy = brief
        copy.weekdays = weekdays.sorted { $0.rawValue < $1.rawValue }
        copy.daysPerWeek = nil
        copy.sessionMinutes = minutes
        copy.equipment = equipment
        copy.goal = goal
        return copy
    }

    var chips: [GridItem] {
        [GridItem(.adaptive(minimum: 72), spacing: 8)]
    }

    var options: [Int] {
        Array(Set(minuteOptions + [minutes])).sorted()
    }

    var injuries: String {
        profile.injuries.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var constraintText: String {
        var lines: [String] = []
        if injuries.isEmpty == false {
            lines.append("档案伤病：\(injuries)")
        }
        if brief.avoid.isEmpty == false {
            lines.append("这次避开：\(brief.avoid.joined(separator: "、"))")
        }
        return lines.joined(separator: "；")
    }

    func toggle(_ day: Weekday) {
        if let index = weekdays.firstIndex(of: day) {
            guard weekdays.count > 1 else { return }
            weekdays.remove(at: index)
        } else {
            weekdays.append(day)
            weekdays.sort { $0.rawValue < $1.rawValue }
        }
    }

    func toggle(_ item: Equipment) {
        if let index = equipment.firstIndex(of: item) {
            guard equipment.count > 1 else { return }
            equipment.remove(at: index)
        } else {
            equipment.append(item)
        }
    }

    func sourceText(for field: PlanBriefField) -> String {
        switch field {
        case .weekdays:
            return Set(weekdays) == Set(profile.availableWeekdays) ? "沿用档案" : "你说的"
        case .sessionMinutes:
            return minutes == profile.sessionMinutes ? "沿用档案" : "你说的"
        case .equipment:
            return Set(equipment) == Set(profile.equipment) ? "沿用档案" : "你说的"
        case .goal:
            return goal == profile.goal ? "沿用档案" : "你说的"
        case .focus:
            return "你说的"
        case .avoid:
            return brief.avoid.isEmpty ? "沿用档案" : "你说的"
        }
    }
}
