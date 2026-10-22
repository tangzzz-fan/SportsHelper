import Foundation
import DongKeCore

enum SampleData {
    static let plan = WorkoutPlan(
        meta: PlanMeta(
            title: "居家减脂 · 4 周",
            goal: .loseFat,
            level: .beginner,
            daysPerWeek: 3,
            sessionMinutes: 30
        ),
        days: [
            PlanDay(
                dayIndex: 0,
                weekday: .thursday,
                isRestDay: false,
                title: "下肢力量",
                scheduledTime: TimeOfDay(hour: 20, minute: 30),
                estimatedMinutes: 30,
                blocks: [
                    ExerciseBlock(
                        blockId: "b0",
                        kind: .main,
                        title: "下肢力量",
                        rounds: 1,
                        restBetweenItemsSec: 90,
                        restBetweenRoundsSec: 0,
                        items: [
                            ExercisePrescription(
                                itemId: "d0-1",
                                catalogId: "squat",
                                name: "深蹲",
                                sets: 4,
                                target: SetTarget(type: .reps, value: 12, perSide: false),
                                restSec: 72,
                                tempo: "2-0-2",
                                load: Load(type: .bodyweight, value: 0)
                            ),
                            ExercisePrescription(
                                itemId: "d0-2",
                                catalogId: "lunge",
                                name: "弓步蹲",
                                sets: 3,
                                target: SetTarget(type: .reps, value: 10, perSide: true),
                                restSec: 60,
                                tempo: "2-0-2",
                                load: Load(type: .bodyweight, value: 0)
                            ),
                            ExercisePrescription(
                                itemId: "d0-3",
                                catalogId: "glute_bridge",
                                name: "臀桥",
                                sets: 3,
                                target: SetTarget(type: .reps, value: 15, perSide: false),
                                restSec: 60,
                                tempo: "2-1-2",
                                load: Load(type: .bodyweight, value: 0)
                            ),
                            ExercisePrescription(
                                itemId: "d0-4",
                                catalogId: "wall_sit",
                                name: "靠墙静蹲",
                                sets: 2,
                                target: SetTarget(type: .durationSec, value: 45, perSide: false),
                                restSec: 60,
                                tempo: "",
                                load: Load(type: .bodyweight, value: 0)
                            )
                        ]
                    )
                ]
            ),
            PlanDay(
                dayIndex: 1,
                weekday: .saturday,
                isRestDay: false,
                title: "上肢与核心",
                scheduledTime: TimeOfDay(hour: 20, minute: 30),
                estimatedMinutes: 28,
                blocks: [
                    ExerciseBlock(
                        blockId: "b1",
                        kind: .main,
                        title: "上肢与核心",
                        rounds: 1,
                        restBetweenItemsSec: 75,
                        restBetweenRoundsSec: 0,
                        items: [
                            ExercisePrescription(
                                itemId: "d1-1",
                                catalogId: "push_up",
                                name: "俯卧撑",
                                sets: 3,
                                target: SetTarget(type: .reps, value: 10, perSide: false),
                                restSec: 75,
                                tempo: "2-0-2",
                                load: Load(type: .bodyweight, value: 0)
                            ),
                            ExercisePrescription(
                                itemId: "d1-2",
                                catalogId: "dumbbell_row",
                                name: "哑铃划船",
                                sets: 3,
                                target: SetTarget(type: .reps, value: 12, perSide: true),
                                restSec: 75,
                                tempo: "2-0-2",
                                load: Load(type: .dumbbell, value: 8)
                            ),
                            ExercisePrescription(
                                itemId: "d1-3",
                                catalogId: "plank",
                                name: "平板支撑",
                                sets: 3,
                                target: SetTarget(type: .durationSec, value: 40, perSide: false),
                                restSec: 60,
                                tempo: "",
                                load: Load(type: .bodyweight, value: 0)
                            )
                        ]
                    )
                ]
            ),
            PlanDay(
                dayIndex: 2,
                weekday: .sunday,
                isRestDay: true,
                title: "休息",
                scheduledTime: nil,
                estimatedMinutes: 0,
                blocks: []
            )
        ],
        source: .manual
    )

    static func weekday(for date: Date) -> Weekday {
        let system = Calendar.current.component(.weekday, from: date)
        return Weekday(systemWeekday: system) ?? .monday
    }

    static func trainingDayIndex(for date: Date) -> Int {
        let weekday = Self.weekday(for: date)
        if let match = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay }) {
            return match.dayIndex
        }
        return plan.days.first(where: { !$0.isRestDay })?.dayIndex ?? 0
    }

    static func nextTrainingDay(after date: Date) -> PlanDay? {
        let ordered = Weekday.allCases
        let startIndex = ordered.firstIndex(of: Self.weekday(for: date)) ?? 0
        for offset in 1...7 {
            let weekday = ordered[(startIndex + offset) % ordered.count]
            if let day = plan.days.first(where: { $0.weekday == weekday && !$0.isRestDay }) {
                return day
            }
        }
        return nil
    }
}
