import XCTest

/// 唯一一条 UI 测试：重量落库后杀掉重进还在不在。
///
/// 单测（`DongKeCoreTests`）不碰 SwiftData，`SetLog → SetLogEntity → SQLite →
/// 重开 → PersonalRecords → 训练页` 这条链断在哪一层，只有它能看出来。
/// 不进默认测试，用 `scripts/ui-test.sh` 单独跑——理由见 `docs/HANDOFF.md` §6.6。
final class LoadPersistenceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DK_PREVIEW"] = "workout"
        app.launchEnvironment["DK_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["DK_WORKOUT_LOAD"] = "1"
        // 重量档位已经在设置里选过：不让首次提问的面板挡住训练页。
        app.launchArguments += ["-dk.load.rackAsked", "YES"]
        app.launch()
        return app
    }

    func testWeightSurvivesRelaunch() {
        let app = launchApp()

        let dose = app.buttons["workout.load.adjust"]
        XCTAssertTrue(dose.waitForExistence(timeout: 20), "训练页没出现重量行")

        // 加一档，记住加完之后的剂量行——不写死 8kg，那条断言会在第二次跑时失败。
        dose.tap()
        let plus = app.buttons["workout.load.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "重量面板没打开")
        plus.tap()
        app.buttons["workout.load.done"].tap()

        let adjusted = app.buttons["workout.load.adjust"].label

        let complete = app.buttons["workout.completeSet"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "完成按钮不可见")
        complete.tap()

        // 杀掉重进：内存里的 loadOverrides 没了，只能从库里读回来。
        app.terminate()
        app.launch()

        let afterRelaunch = app.buttons["workout.load.adjust"]
        XCTAssertTrue(afterRelaunch.waitForExistence(timeout: 20), "重开后训练页没回来")
        XCTAssertEqual(
            afterRelaunch.label,
            adjusted,
            "重开后应默认上次用的重量"
        )
    }
}
