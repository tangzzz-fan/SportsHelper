import XCTest

final class DongKeRestDayUITests: DongKeUITestCase {
    func testRestDayStartStillOpensWorkout() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        text(A11y.Today.title)
        let start = button(A11y.Today.start)
        XCTAssertEqual(start.label, "提前练一次", "今天不是休息日，这条用例的前提不成立")

        tap(start)

        XCTAssertTrue(
            app.buttons[A11y.Workout.completeSet].waitForExistence(timeout: 10),
            "点了「提前练一次」没有进入训练页"
        )
    }

    func testStartButtonRespondsOutsideItsLabel() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])
        text(A11y.Today.title)

        let start = button(A11y.Today.start)
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5)).tap()

        XCTAssertTrue(
            app.buttons[A11y.Workout.completeSet].waitForExistence(timeout: 10),
            "点按钮左侧空白没有进入训练页，说明可点区域仍然只有文字"
        )
    }
}
