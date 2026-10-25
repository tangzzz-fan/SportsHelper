import Testing
@testable import DongKeCore

struct WorkoutPromptTests {
    private func hold(_ seconds: Int) -> SetTarget {
        SetTarget(type: .durationSec, value: seconds, perSide: false)
    }

    private func reps(_ count: Int) -> SetTarget {
        SetTarget(type: .reps, value: count, perSide: false)
    }

    @Test("静态动作排两条：中段要领、最后三秒")
    func staticTargetPlansFocusAndRemaining() {
        let planned = WorkoutPromptPlanner.prompts(target: hold(30), cue: "小腹收紧")
        #expect(planned == [
            TimedPrompt(atSecond: 10, prompt: .focus("小腹收紧")),
            TimedPrompt(atSecond: 27, prompt: .remaining(secondsLeft: 3))
        ])
    }

    @Test("动态动作不排提示，免得数数打断节奏")
    func repsTargetHasNoPrompts() {
        #expect(WorkoutPromptPlanner.prompts(target: reps(12), cue: "小腹收紧").isEmpty)
    }

    @Test("少于十二秒的静态动作组内一句都不念")
    func shortHoldHasNoPrompts() {
        #expect(WorkoutPromptPlanner.prompts(target: hold(10), cue: "小腹收紧").isEmpty)
        #expect(WorkoutPromptPlanner.prompts(target: hold(11), cue: "小腹收紧").isEmpty)
    }

    @Test("没有要领时只剩最后三秒")
    func missingCueSkipsFocus() {
        let planned = WorkoutPromptPlanner.prompts(target: hold(30), cue: "   ")
        #expect(planned == [TimedPrompt(atSecond: 27, prompt: .remaining(secondsLeft: 3))])
    }

    @Test("两条提示之间至少隔两秒，不连发")
    func promptsNeverOverlap() {
        for seconds in [12, 13, 14, 15, 16, 20, 45, 60] {
            let planned = WorkoutPromptPlanner.prompts(target: hold(seconds), cue: "小腹收紧")
            let gaps = zip(planned, planned.dropFirst()).map { $1.atSecond - $0.atSecond }
            #expect(gaps.allSatisfy { $0 >= 2 }, "\(seconds) 秒的组出现连发：\(planned)")
        }
    }

    @Test("倒数是组内最后一条，不再补「时间到」")
    func remainingIsAlwaysLast() {
        for seconds in [12, 30, 90] {
            let planned = WorkoutPromptPlanner.prompts(target: hold(seconds), cue: "收腹")
            #expect(planned.last == TimedPrompt(atSecond: seconds - 3, prompt: .remaining(secondsLeft: 3)))
            #expect(planned.contains { if case .remaining(let left) = $0.prompt { left == 3 } else { false } })
        }
    }
}
