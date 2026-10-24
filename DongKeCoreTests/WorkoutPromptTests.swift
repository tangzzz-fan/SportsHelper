import Testing
@testable import DongKeCore

struct WorkoutPromptTests {
    private func hold(_ seconds: Int) -> SetTarget {
        SetTarget(type: .durationSec, value: seconds, perSide: false)
    }

    private func reps(_ count: Int) -> SetTarget {
        SetTarget(type: .reps, value: count, perSide: false)
    }

    @Test("静态动作排三条：要领、剩余三秒、时间到")
    func staticTargetPlansFocusRemainingAndTimeUp() {
        let planned = WorkoutPromptPlanner.prompts(
            target: hold(30),
            cue: "小腹收紧",
            isLastSet: false,
            allowsEncouragement: false
        )
        #expect(planned == [
            TimedPrompt(atSecond: 10, prompt: .focus("小腹收紧")),
            TimedPrompt(atSecond: 27, prompt: .remaining(secondsLeft: 3)),
            TimedPrompt(atSecond: 30, prompt: .timeUp)
        ])
    }

    @Test("最后一组且允许鼓励时，多一条加油")
    func encouragementOnlyOnLastSet() {
        let planned = WorkoutPromptPlanner.prompts(
            target: hold(30),
            cue: "小腹收紧",
            isLastSet: true,
            allowsEncouragement: true
        )
        #expect(planned.count == 4)
        #expect(planned.contains(TimedPrompt(atSecond: 25, prompt: .encourage(secondsLeft: 5))))

        let earlier = WorkoutPromptPlanner.prompts(
            target: hold(30),
            cue: "小腹收紧",
            isLastSet: false,
            allowsEncouragement: true
        )
        #expect(earlier.contains { if case .encourage = $0.prompt { true } else { false } } == false)
    }

    @Test("动态动作不排中段提示，免得数数打断节奏")
    func repsTargetHasNoPrompts() {
        #expect(WorkoutPromptPlanner.prompts(
            target: reps(12),
            cue: "小腹收紧",
            isLastSet: true,
            allowsEncouragement: true
        ).isEmpty)
    }

    @Test("少于十二秒的静态动作只报时间到，不念要领也不倒数")
    func shortHoldOnlyReportsTimeUp() {
        #expect(WorkoutPromptPlanner.prompts(
            target: hold(10),
            cue: "小腹收紧",
            isLastSet: true,
            allowsEncouragement: true
        ) == [TimedPrompt(atSecond: 10, prompt: .timeUp)])
    }

    @Test("没有要领时只报剩余与时间到")
    func missingCueSkipsFocus() {
        let planned = WorkoutPromptPlanner.prompts(
            target: hold(30),
            cue: "   ",
            isLastSet: false,
            allowsEncouragement: false
        )
        #expect(planned == [
            TimedPrompt(atSecond: 27, prompt: .remaining(secondsLeft: 3)),
            TimedPrompt(atSecond: 30, prompt: .timeUp)
        ])
    }

    @Test("两条提示之间至少隔两秒，不连发")
    func promptsNeverOverlap() {
        for seconds in [10, 12, 13, 14, 15, 16, 20, 45, 60] {
            let planned = WorkoutPromptPlanner.prompts(
                target: hold(seconds),
                cue: "小腹收紧",
                isLastSet: true,
                allowsEncouragement: true
            )
            let gaps = zip(planned, planned.dropFirst()).map { $1.atSecond - $0.atSecond }
            #expect(gaps.allSatisfy { $0 >= 2 }, "\(seconds) 秒的组出现连发：\(planned)")
        }
    }

    @Test("时间到落在最后一条，不会被倒数压住")
    func timeUpIsAlwaysLast() {
        for seconds in [5, 10, 12, 30, 90] {
            let planned = WorkoutPromptPlanner.prompts(
                target: hold(seconds),
                cue: "收腹",
                isLastSet: true,
                allowsEncouragement: true
            )
            #expect(planned.last == TimedPrompt(atSecond: seconds, prompt: .timeUp))
        }
    }
}
