import Foundation
import Testing
@testable import DongKeCore

struct SetTimerDriverTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func holdStep(_ seconds: Int) -> FlowStep {
        .set(
            prescriptionId: "p1",
            setIndex: 1,
            target: SetTarget(type: .durationSec, value: seconds, perSide: false),
            restAfterSec: 0
        )
    }

    private func repsStep(_ count: Int) -> FlowStep {
        .set(
            prescriptionId: "p1",
            setIndex: 1,
            target: SetTarget(type: .reps, value: count, perSide: false),
            restAfterSec: 0
        )
    }

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    @Test("静态动作起表，倒计时显示整套时长")
    func startsForTimedStep() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(30), stepIndex: 0, isResting: false, now: start)
        #expect(driver.showsCountdown)
        #expect(driver.remainingDisplay == 30)
        #expect(driver.elapsedSeconds(now: start) == 0)
    }

    @Test("次数型动作不起表，不显示倒计时")
    func ignoresRepsStep() {
        var driver = SetTimerDriver()
        driver.sync(step: repsStep(12), stepIndex: 0, isResting: false, now: start)
        #expect(driver.showsCountdown == false)
        #expect(driver.remainingDisplay == 0)
        #expect(driver.state == .idle)
    }

    @Test("休息步骤占据当前位时停表，倒计时消失")
    func pausesDuringRest() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(30), stepIndex: 0, isResting: false, now: start)
        #expect(driver.showsCountdown)

        driver.sync(step: holdStep(30), stepIndex: 0, isResting: true, now: at(5))
        #expect(driver.showsCountdown == false)
        #expect(driver.state == .idle)
    }

    @Test("换到下一组重新起表，不沿用上一组的秒数")
    func restartsOnNextSet() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(30), stepIndex: 0, isResting: false, now: start)
        driver.tick(now: at(20))
        #expect(driver.remainingDisplay == 10)

        driver.sync(step: holdStep(30), stepIndex: 2, isResting: false, now: at(25))
        #expect(driver.remainingDisplay == 30)
        #expect(driver.elapsedSeconds(now: at(25)) == 0)
    }

    @Test("同一步骤重复 sync 不会重置倒计时")
    func repeatedSyncKeepsRunning() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(30), stepIndex: 0, isResting: false, now: start)
        driver.tick(now: at(12))
        #expect(driver.remainingDisplay == 18)

        driver.sync(step: holdStep(30), stepIndex: 0, isResting: false, now: at(12.25))
        #expect(driver.remainingDisplay == 18)
    }

    @Test("到点只报一次，剩余归零后继续 tick 不重复计数")
    func reachesZeroOnce() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(12), stepIndex: 0, isResting: false, now: start)

        driver.tick(now: at(12))
        #expect(driver.reachedZeroCount == 1)
        #expect(driver.remainingDisplay == 0)
        #expect(driver.showsCountdown)

        driver.tick(now: at(13))
        driver.tick(now: at(20))
        #expect(driver.reachedZeroCount == 1)
    }

    @Test("到点后继续撑，已用时长停在整段，播报不重复触发")
    func elapsedStopsAtTotal() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(12), stepIndex: 0, isResting: false, now: start)
        driver.tick(now: at(12))
        #expect(driver.elapsedSeconds(now: at(30)) == 12)
    }

    @Test("离开训练时清空，下一个动作从零开始")
    func resetClearsEverything() {
        var driver = SetTimerDriver()
        driver.sync(step: holdStep(30), stepIndex: 0, isResting: false, now: start)
        driver.tick(now: at(10))

        driver.reset()
        #expect(driver.state == .idle)
        #expect(driver.showsCountdown == false)
        #expect(driver.remainingDisplay == 0)
        #expect(driver.elapsedSeconds(now: at(10)) == 0)
    }

    @Test("不是静态动作时反复 sync 不产生多余状态变化")
    func idleSyncIsStable() {
        var driver = SetTimerDriver()
        for second in 0..<5 {
            driver.sync(step: repsStep(12), stepIndex: 0, isResting: false, now: at(Double(second)))
        }
        #expect(driver == SetTimerDriver())
    }
}
