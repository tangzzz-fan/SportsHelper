import XCTest

final class DongKeVoiceUITests: DongKeUITestCase {
    func testVoiceInputFillsSentence() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_AI_FAKE": "1",
            "DK_VOICE_TRANSCRIPT": "每周二四，每次 45 分钟，有哑铃"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        tap(button(A11y.Plan.importPlan))

        let mic = app.buttons[A11y.Import.voiceStart]
        XCTAssertTrue(mic.waitForExistence(timeout: 10), "麦克风按钮没出现")
        if mic.isHittable == false {
            app.swipeUp()
        }
        tap(mic)

        let field = any(A11y.Import.aiSentence)
        let filled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "每周二四，每次 45 分钟，有哑铃"),
            object: field
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [filled], timeout: 10),
            .completed,
            "转写结果没有回填到一句话输入框，当前值：\(String(describing: field.value))"
        )
    }

    func testVoiceDeniedShowsSettingsPath() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_AI_FAKE": "1",
            "DK_VOICE_STUB": "denySpeech"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        tap(button(A11y.Plan.importPlan))

        let mic = app.buttons[A11y.Import.voiceStart]
        XCTAssertTrue(mic.waitForExistence(timeout: 10), "麦克风按钮没出现")
        if mic.isHittable == false {
            app.swipeUp()
        }
        tap(mic)

        XCTAssertTrue(
            app.buttons[A11y.Import.voiceSettings].waitForExistence(timeout: 8),
            "权限被拒时没有给「去设置」的出口"
        )
        XCTAssertTrue(
            app.buttons[A11y.Import.voiceStart].exists,
            "失败后连重试入口都消失了"
        )
    }

    func testVoiceOnlineConsentFillsSentence() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_AI_FAKE": "1",
            "DK_VOICE_STUB": "onDeviceMissing"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        tap(button(A11y.Plan.importPlan))

        let mic = app.buttons[A11y.Import.voiceStart]
        XCTAssertTrue(mic.waitForExistence(timeout: 10), "麦克风按钮没出现")
        if mic.isHittable == false {
            app.swipeUp()
        }
        tap(mic)

        let accept = app.buttons[A11y.Import.voiceOnlineAccept]
        XCTAssertTrue(accept.waitForExistence(timeout: 8), "没有先提示会用 Apple 的语音服务")
        if accept.isHittable == false {
            app.swipeUp()
        }
        tap(accept)

        let field = any(A11y.Import.aiSentence)
        let filled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "每周二四"),
            object: field
        )
        XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 10), .completed, "同意联网后没有回填")
    }
}
