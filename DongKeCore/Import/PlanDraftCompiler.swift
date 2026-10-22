import Foundation

public struct CompiledDraft: Equatable, Sendable {
    public var plan: WorkoutPlan
    public var assumptions: [String]
    public var unmappedNames: [String]
    public var guessedItems: [String: GuessedRow]
}

public enum PlanDraftCompiler {
    public static let defaultSets = 3
    public static let defaultReps = 12
    public static let defaultHoldSeconds = 30
    public static let defaultRestSeconds = 60

    public static func compile(
        _ draft: PlanDraft,
        exercises: UserExerciseCatalog = .empty,
        now: Date = Date()
    ) -> CompiledDraft {
        var assumptions: [String] = []

        var assigned: [Weekday: [DraftItem]] = [:]
        var labels: [Weekday: String] = [:]
        var rounds: [Weekday: Int] = [:]
        var droppedItems = 0

        for day in draft.days where day.items.isEmpty == false {
            if let weekday = day.weekday {
                if assigned[weekday] != nil {
                    assumptions.append("\(weekday.chineseName)写了两次，已合并到一天")
                }
                assigned[weekday, default: []].append(contentsOf: day.items)
                if labels[weekday] == nil { labels[weekday] = day.label }
                rounds[weekday] = max(rounds[weekday] ?? 1, day.rounds ?? 1)
                continue
            }

            guard let free = Weekday.allCases.first(where: { assigned[$0] == nil }) else {
                droppedItems += day.items.count
                continue
            }
            assigned[free] = day.items
            labels[free] = day.label
            rounds[free] = max(1, day.rounds ?? 1)
            assumptions.append("「\(day.label)」没写星期，按\(free.chineseName)排")
        }

        if droppedItems > 0 {
            assumptions.append("一周只能放 7 天，多出的 \(droppedItems) 个动作已略去")
        }

        var missingSets = 0
        var missingDose = 0
        var missingRest = 0
        var unmapped: [String] = []
        var guessedItems: [String: GuessedRow] = [:]
        var filledFromMine: [String] = []

        var planDays: [PlanDay] = []
        for weekday in Weekday.allCases {
            guard let items = assigned[weekday], items.isEmpty == false else {
                planDays.append(PlanDay(
                    dayIndex: weekday.rawValue,
                    weekday: weekday,
                    isRestDay: true,
                    title: "休息",
                    scheduledTime: nil,
                    estimatedMinutes: 0,
                    blocks: [],
                    notes: ""
                ))
                continue
            }

            var prescriptions: [ExercisePrescription] = []
            for (offset, item) in items.enumerated() {
                let entry = item.catalogId.flatMap { ExerciseLibrary.entry(for: $0) }
                let mine = item.catalogId == nil ? exercises.exercise(named: item.rawName) : nil
                if item.catalogId == nil, mine == nil, unmapped.contains(item.rawName) == false {
                    unmapped.append(item.rawName)
                }
                if mine != nil, item.sets == nil || item.value == nil || item.restSec == nil,
                   filledFromMine.contains(item.rawName) == false {
                    filledFromMine.append(item.rawName)
                }

                let sets = item.sets ?? mine?.defaultSets ?? defaultSets
                if item.sets == nil, mine == nil { missingSets += 1 }

                let target: SetTarget
                if let value = item.value {
                    target = SetTarget(
                        type: item.targetType ?? (entry?.isStatic == true ? .durationSec : .reps),
                        value: value,
                        perSide: item.perSide
                    )
                } else if let mine {
                    target = SetTarget(
                        type: mine.isStatic ? .durationSec : .reps,
                        value: mine.defaultValue,
                        perSide: item.perSide
                    )
                } else {
                    missingDose += 1
                    target = entry?.isStatic == true
                        ? SetTarget(type: .durationSec, value: defaultHoldSeconds, perSide: item.perSide)
                        : SetTarget(type: .reps, value: defaultReps, perSide: item.perSide)
                }

                if item.restSec == nil, mine == nil { missingRest += 1 }
                let equipment = entry?.equipment ?? .bodyweight
                let itemId = "d\(weekday.rawValue)-i\(offset + 1)"

                if let modifier = item.reviewModifier, let entry {
                    guessedItems[itemId] = GuessedRow(
                        originalName: item.rawName,
                        catalogName: entry.name,
                        kind: .approximate(modifier: modifier)
                    )
                } else if item.usedMemory, let entry {
                    guessedItems[itemId] = GuessedRow(
                        originalName: item.rawName,
                        catalogName: entry.name,
                        kind: .memory
                    )
                }

                prescriptions.append(ExercisePrescription(
                    itemId: itemId,
                    catalogId: item.catalogId ?? mine?.id ?? CustomExerciseId.id(for: item.rawName),
                    name: entry?.name ?? mine?.name ?? item.rawName,
                    sets: sets,
                    target: target,
                    restSec: item.restSec ?? mine?.restSec ?? defaultRestSeconds,
                    load: Load(type: equipment == .dumbbell ? .dumbbell : .bodyweight, value: 0),
                    notes: item.assumptions.joined(separator: "；")
                ))
            }

            let dayRounds = max(1, rounds[weekday] ?? 1)
            let block = ExerciseBlock(
                blockId: "b1",
                kind: dayRounds > 1 ? .circuit : .main,
                title: dayRounds > 1 ? "循环训练" : (labels[weekday] ?? "主训练"),
                rounds: dayRounds,
                restBetweenItemsSec: 0,
                restBetweenRoundsSec: dayRounds > 1 ? 60 : 0,
                items: prescriptions
            )

            var day = PlanDay(
                dayIndex: weekday.rawValue,
                weekday: weekday,
                isRestDay: false,
                title: labels[weekday] ?? "训练",
                scheduledTime: nil,
                estimatedMinutes: 0,
                blocks: [block],
                notes: ""
            )
            day.estimatedMinutes = max(1, PlanEditing.estimatedMinutes(for: day))
            planDays.append(day)
        }

        if missingSets > 0 { assumptions.append("有 \(missingSets) 项没写组数，按 \(defaultSets) 组") }
        if missingDose > 0 { assumptions.append("有 \(missingDose) 项没写次数或时长，按 \(defaultReps) 次 / \(defaultHoldSeconds) 秒") }
        if missingRest > 0 { assumptions.append("有 \(missingRest) 项没写休息，按 \(defaultRestSeconds) 秒") }

        for item in draft.days.flatMap(\.items) {
            assumptions.append(contentsOf: item.assumptions)
            let entry = item.catalogId.flatMap { ExerciseLibrary.entry(for: $0) }
            if let modifier = item.reviewModifier, let entry {
                assumptions.append("「\(item.rawName)」按最接近的「\(entry.name)」计入，原文带「\(modifier)」，请确认是不是你要的动作")
            }
            if item.usedMemory, let entry {
                assumptions.append("「\(item.rawName)」按你上次的选择记为「\(entry.name)」")
            }
        }
        for name in filledFromMine {
            assumptions.append("「\(name)」没写全剂量，按我的动作里的默认值补齐")
        }
        for name in unmapped {
            assumptions.append("「\(name)」不在动作库里，按自定义动作保留")
        }

        let trainingCount = planDays.filter { !$0.isRestDay }.count
        let longest = planDays.map(\.estimatedMinutes).max() ?? 30

        let plan = WorkoutPlan(
            meta: PlanMeta(
                title: draft.title?.isEmpty == false ? draft.title! : "我的训练计划",
                goal: .generalFitness,
                level: .beginner,
                daysPerWeek: max(1, trainingCount),
                sessionMinutes: min(120, max(5, longest))
            ),
            days: planDays,
            cautions: draft.cautions.isEmpty ? ["关节疼痛须停训，动作幅度以无痛为限"] : draft.cautions,
            source: .pasteText
        )

        return CompiledDraft(
            plan: plan,
            assumptions: uniqued(assumptions),
            unmappedNames: unmapped,
            guessedItems: guessedItems
        )
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
