import Foundation

public enum Sex: String, Codable, Sendable, CaseIterable {
    case female
    case male
    case unspecified

    public var chineseName: String {
        switch self {
        case .female: "女"
        case .male: "男"
        case .unspecified: "不说"
        }
    }
}

public enum Equipment: String, Codable, Sendable, CaseIterable {
    case bodyweight
    case dumbbell
    case band
    case kettlebell
    case bench

    public var chineseName: String {
        switch self {
        case .bodyweight: "徒手"
        case .dumbbell: "哑铃"
        case .band: "弹力带"
        case .kettlebell: "壶铃"
        case .bench: "卧凳"
        }
    }
}

public struct UserProfile: Codable, Equatable, Sendable {
    public var heightCm: Int
    public var weightKg: Double
    public var age: Int
    public var sex: Sex
    public var goal: PlanGoal
    public var level: TrainingLevel
    public var availableWeekdays: [Weekday]
    public var sessionMinutes: Int
    public var equipment: [Equipment]
    public var injuries: String
    public var reminderEnabled: Bool
    public var reminderTime: TimeOfDay
    public var onboardedAt: Date?

    public init(
        heightCm: Int = 170,
        weightKg: Double = 65,
        age: Int = 30,
        sex: Sex = .unspecified,
        goal: PlanGoal = .loseFat,
        level: TrainingLevel = .beginner,
        availableWeekdays: [Weekday] = [.monday, .wednesday, .friday],
        sessionMinutes: Int = 30,
        equipment: [Equipment] = [.bodyweight],
        injuries: String = "",
        reminderEnabled: Bool = true,
        reminderTime: TimeOfDay = TimeOfDay(hour: 20, minute: 30),
        onboardedAt: Date? = nil
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.age = age
        self.sex = sex
        self.goal = goal
        self.level = level
        self.availableWeekdays = availableWeekdays
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.injuries = injuries
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.onboardedAt = onboardedAt
    }
}

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case basics = 0
    case goal = 1
    case level = 2
    case availability = 3
    case healthAndReminder = 4

    public var title: String {
        switch self {
        case .basics: "先认识一下"
        case .goal: "你想练成什么样"
        case .level: "从哪一档开始"
        case .availability: "什么时候能练"
        case .healthAndReminder: "最后两件事"
        }
    }

    public var subtitle: String {
        switch self {
        case .basics: "这些只用来估算强度和热量，不上传"
        case .goal: "计划会围绕这个目标排优先级"
        case .level: "选低一档比选高一档安全"
        case .availability: "训练日与每次时长，决定排期"
        case .healthAndReminder: "伤病会被避开；提醒按训练日排"
        }
    }

    public var index: Int { rawValue }
    public var total: Int { OnboardingStep.allCases.count }
}

public struct OnboardingDraft: Equatable, Sendable {
    public var profile: UserProfile

    public init(profile: UserProfile = UserProfile()) {
        self.profile = profile
    }

    public static let heightRange = 120...230
    public static let weightRange = 30.0...250.0
    public static let ageRange = 14...90
    public static let sessionOptions = [20, 30, 45, 60]

    public func isStepValid(_ step: OnboardingStep) -> Bool {
        switch step {
        case .basics:
            return OnboardingDraft.heightRange.contains(profile.heightCm)
                && OnboardingDraft.weightRange.contains(profile.weightKg)
                && OnboardingDraft.ageRange.contains(profile.age)
        case .goal:
            return true
        case .level:
            return OnboardingDraft.sessionOptions.contains(profile.sessionMinutes)
        case .availability:
            return !profile.availableWeekdays.isEmpty && !profile.equipment.isEmpty
        case .healthAndReminder:
            return true
        }
    }

    public func canAdvance(from step: OnboardingStep) -> Bool {
        isStepValid(step)
    }

    public var isComplete: Bool {
        OnboardingStep.allCases.allSatisfy { isStepValid($0) }
    }

    public mutating func toggleWeekday(_ weekday: Weekday) {
        if let index = profile.availableWeekdays.firstIndex(of: weekday) {
            profile.availableWeekdays.remove(at: index)
        } else {
            profile.availableWeekdays.append(weekday)
            profile.availableWeekdays.sort { $0.rawValue < $1.rawValue }
        }
    }

    public mutating func toggleEquipment(_ item: Equipment) {
        if let index = profile.equipment.firstIndex(of: item) {
            guard profile.equipment.count > 1 else { return }
            profile.equipment.remove(at: index)
        } else {
            profile.equipment.append(item)
        }
    }

    public func completedProfile(now: Date) -> UserProfile {
        var copy = profile
        copy.onboardedAt = now
        return copy
    }
}

extension PlanGoal {
    public var chineseName: String {
        switch self {
        case .loseFat: "减脂"
        case .buildMuscle: "增肌"
        case .endurance: "耐力"
        case .generalFitness: "综合体能"
        case .mobility: "灵活性"
        }
    }
}

extension TrainingLevel {
    public var chineseName: String {
        switch self {
        case .beginner: "刚开始"
        case .intermediate: "练过一阵"
        case .advanced: "长期训练"
        }
    }
}
