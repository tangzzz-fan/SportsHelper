import Foundation

public enum PlanBriefField: String, CaseIterable, Sendable {
    case weekdays
    case sessionMinutes
    case equipment
    case goal
    case focus
    case avoid
}

public struct PlanBrief: Equatable, Sendable {
    public var sentence: String
    public var weekdays: [Weekday]?
    public var daysPerWeek: Int?
    public var sessionMinutes: Int?
    public var equipment: [Equipment]?
    public var goal: PlanGoal?
    public var focus: [String]
    public var avoid: [String]
    public var unparsed: [String]
    public var isVague: Bool

    public init(
        sentence: String,
        weekdays: [Weekday]? = nil,
        daysPerWeek: Int? = nil,
        sessionMinutes: Int? = nil,
        equipment: [Equipment]? = nil,
        goal: PlanGoal? = nil,
        focus: [String] = [],
        avoid: [String] = [],
        unparsed: [String] = [],
        isVague: Bool = false
    ) {
        self.sentence = sentence
        self.weekdays = weekdays
        self.daysPerWeek = daysPerWeek
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.goal = goal
        self.focus = focus
        self.avoid = avoid
        self.unparsed = unparsed
        self.isVague = isVague
    }

    public var overriddenFields: Set<PlanBriefField> {
        var fields: Set<PlanBriefField> = []
        if weekdays != nil || daysPerWeek != nil { fields.insert(.weekdays) }
        if sessionMinutes != nil { fields.insert(.sessionMinutes) }
        if equipment != nil { fields.insert(.equipment) }
        if goal != nil { fields.insert(.goal) }
        if focus.isEmpty == false { fields.insert(.focus) }
        if avoid.isEmpty == false { fields.insert(.avoid) }
        return fields
    }

    public func resolved(against profile: UserProfile) -> EffectivePlanBrief {
        let minutes = min(120, max(5, sessionMinutes ?? profile.sessionMinutes))
        let gear = (equipment?.isEmpty == false ? equipment : profile.equipment) ?? []
        return EffectivePlanBrief(
            weekdays: resolvedWeekdays(against: profile),
            sessionMinutes: minutes,
            equipment: gear.isEmpty ? [.bodyweight] : gear,
            goal: goal ?? profile.goal,
            focus: focus,
            avoid: avoid,
            injuries: profile.injuries,
            maxExercises: max(3, min(8, minutes / 5)),
            maxSets: max(6, min(30, minutes / 2))
        )
    }

    private func resolvedWeekdays(against profile: UserProfile) -> [Weekday] {
        if let weekdays, weekdays.isEmpty == false {
            return Self.uniqued(weekdays).sorted { $0.rawValue < $1.rawValue }
        }

        let target = min(7, max(1, daysPerWeek ?? profile.availableWeekdays.count))
        var days = Self.uniqued(profile.availableWeekdays)
        if days.count >= target {
            return Array(days.prefix(target)).sorted { $0.rawValue < $1.rawValue }
        }
        for day in Weekday.allCases where days.contains(day) == false {
            days.append(day)
            if days.count == target { break }
        }
        if days.isEmpty {
            days = Array(Weekday.allCases.prefix(target))
        }
        return days.sorted { $0.rawValue < $1.rawValue }
    }

    private static func uniqued(_ values: [Weekday]) -> [Weekday] {
        var seen: Set<Weekday> = []
        return values.filter { seen.insert($0).inserted }
    }
}

public struct EffectivePlanBrief: Equatable, Sendable {
    public var weekdays: [Weekday]
    public var sessionMinutes: Int
    public var equipment: [Equipment]
    public var goal: PlanGoal
    public var focus: [String]
    public var avoid: [String]
    public var injuries: String
    public var maxExercises: Int
    public var maxSets: Int

    public init(
        weekdays: [Weekday],
        sessionMinutes: Int,
        equipment: [Equipment],
        goal: PlanGoal,
        focus: [String],
        avoid: [String],
        injuries: String,
        maxExercises: Int,
        maxSets: Int
    ) {
        self.weekdays = weekdays
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.goal = goal
        self.focus = focus
        self.avoid = avoid
        self.injuries = injuries
        self.maxExercises = maxExercises
        self.maxSets = maxSets
    }

    public var daysPerWeek: Int { weekdays.count }

    public var weekdayText: String {
        weekdays.map(\.chineseName).joined(separator: "、")
    }

    public var equipmentText: String {
        equipment.map(\.chineseName).joined(separator: "、")
    }
}
