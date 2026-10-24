import XCTest

final class DongKeChainsUITests: DongKeUITestCase {
    func testOnboardingFiveStepsLandOnToday() {
        launchApp()

        XCTAssertTrue(app.staticTexts["先认识一下"].waitForExistence(timeout: 20))

        for title in ["你想练成什么样", "从哪一档开始", "什么时候能练", "最后两件事"] {
            tap(button(A11y.Onboarding.next))
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "没走到「\(title)」")
        }

        tap(app.switches.firstMatch)
        tap(button(A11y.Onboarding.next))

        text(A11y.Today.title)
        button(A11y.Today.start)
        XCTAssertTrue(app.staticTexts["先认识一下"].waitForExistence(timeout: 3) == false)
    }

    func testOnboardingSkipUsesDefaults() {
        launchApp()

        XCTAssertTrue(app.staticTexts["先认识一下"].waitForExistence(timeout: 20))
        tap(button(A11y.Onboarding.skip))

        text(A11y.Today.title)
        dismissNotificationPromptIfNeeded()
        button(A11y.Today.start)
    }

    func testImportSampleParsedReviewedSaved() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_IMPORT_SAMPLE": "1"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        text(A11y.Plan.title)

        tap(button(A11y.Plan.importPlan))

        let editor = app.textViews[A11y.Import.editor]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        let prefilled = editor.value as? String ?? ""
        XCTAssertTrue(prefilled.contains("深蹲"), "示例文本没预填进来：\(prefilled)")

        tap(button(A11y.Import.parse))
        tap(button(A11y.Import.save))

        XCTAssertTrue(app.staticTexts["增肌计划 第一周"].waitForExistence(timeout: 10), "保存后计划标题没出现")
        XCTAssertTrue(app.textViews[A11y.Import.editor].waitForExistence(timeout: 3) == false, "导入页没有关闭")
    }

    func testImportEmptyKeepsParseDisabled() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        tapTab("计划")
        tap(button(A11y.Plan.importPlan))
        XCTAssertTrue(app.textViews[A11y.Import.editor].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textViews[A11y.Import.editor].value as? String, "")
        XCTAssertFalse(app.buttons.matching(identifier: A11y.Import.parse).firstMatch.isEnabled)

        tap(labeled("取消"))
        XCTAssertTrue(app.textViews[A11y.Import.editor].waitForExistence(timeout: 3) == false)
        button(A11y.Plan.importPlan)
    }

    func testImportTruncatedJSONShowsIncompleteMessage() {
        let truncated = #"{"days":[{"day":"周一","items":[{"name":"深蹲""#
        launchApp(["DK_COMPLETE_ONBOARDING": "1", "DK_IMPORT_PASTE": truncated])

        text(A11y.Today.title)
        tapTab("计划")
        tap(button(A11y.Plan.importPlan))

        XCTAssertTrue(app.textViews[A11y.Import.editor].waitForExistence(timeout: 10))
        tap(button(A11y.Import.parse))

        XCTAssertTrue(
            app.staticTexts["这段内容没粘完整"].waitForExistence(timeout: 5),
            "截断的 JSON 没有提示「没粘完整」"
        )
        XCTAssertFalse(app.buttons[A11y.Import.save].exists, "截断内容不该进入校对页")
    }

    func testQuickAIEntryGoesThroughReview() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_PROFILE_INJURIES": "肩颈不适",
            "DK_AI_FAKE": "1"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        text(A11y.Plan.title)

        let entry = button(A11y.Plan.aiEntry)
        scrollUntilHittable(entry)
        tap(entry)

        let sentence = app.textFields[A11y.Import.aiSentence]
        XCTAssertTrue(sentence.waitForExistence(timeout: 10), "快速入口没出现输入框")
        tap(sentence)
        sentence.typeText("每周三次，每次 30 分钟，有哑铃")

        let generate = button(A11y.Import.aiGenerate)
        scrollUntilHittable(generate)
        tap(generate)

        XCTAssertTrue(
            app.staticTexts["先对一下，再生成"].waitForExistence(timeout: 8),
            "快速入口跳过了理解确认"
        )
        tap(button(A11y.Import.briefConfirm))

        XCTAssertTrue(
            app.buttons[A11y.Import.save].waitForExistence(timeout: 25),
            "生成后没进校对页，可能是直接落库了"
        )
        XCTAssertTrue(app.navigationBars["校对"].exists, "校对页标题不对")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "quick-ai-review"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testBriefConfirmBeforeGenerate() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_BRIEF_SAMPLE": "每周二四，每次 45 分钟，有弹力带，想增肌",
            "DK_AI_FAKE": "1"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        tap(button(A11y.Plan.importPlan))

        let generate = app.buttons[A11y.Import.aiGenerate]
        XCTAssertTrue(generate.waitForExistence(timeout: 10), "一句话生成按钮没出现")
        if generate.isHittable == false {
            app.swipeUp()
        }
        tap(generate)

        XCTAssertTrue(
            app.staticTexts["先对一下，再生成"].waitForExistence(timeout: 5),
            "没有先展示理解确认页"
        )
        XCTAssertTrue(app.buttons["周二"].exists, "没识别出周二")
        XCTAssertTrue(app.buttons["45 分钟"].exists, "没识别出 45 分钟")

        tap(button(A11y.Import.briefConfirm))
        XCTAssertTrue(app.buttons[A11y.Import.save].waitForExistence(timeout: 15), "确认后没有进入校对页")
    }

    func testWorkoutCompleteRestSkipEndSummary() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        text(A11y.Today.title)
        tap(button(A11y.Today.start))

        completeOneSet()
        completeOneSet()
        skipOneSet()
        completeOneSet()

        tap(button(A11y.Workout.end))

        text(A11y.Workout.summaryTitle)
        XCTAssertFalse(text(A11y.Summary.completion).label.isEmpty)

        tap(button(A11y.Summary.done))

        text(A11y.Today.title)
        button(A11y.Today.start)
    }

    func testWorkoutShowsCuesAndAsksBeforeHalving() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        tap(button(A11y.Today.start))

        let cues = app.descendants(matching: .any).matching(identifier: A11y.Workout.cues).firstMatch
        XCTAssertTrue(cues.waitForExistence(timeout: 10), "训练页没有显示动作要点")

        tap(button(A11y.Workout.downgrade))

        let half = button(A11y.Workout.downgradeHalf)
        tap(half)

        let skipRest = app.buttons.matching(identifier: A11y.Workout.skipRest).firstMatch
        XCTAssertTrue(skipRest.waitForExistence(timeout: 10), "减半后没有进入组间休息")
    }

    func testWorkoutControlsReachableAtAccessibilityTextSize() {
        launchApp(
            ["DK_COMPLETE_ONBOARDING": "1", "DK_PREVIEW": "workout"],
            arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )

        let close = button(A11y.Workout.close)
        let end = button(A11y.Workout.end)
        let complete = button(A11y.Workout.completeSet)
        let skip = button(A11y.Workout.skipSet)

        for element in [close, end, complete, skip] {
            XCTAssertTrue(element.isHittable, "最大辅助字号下这个控件点不到：\(element)")
        }
        XCTAssertTrue(app.frame.contains(end.frame), "「结束」超出屏幕")
        XCTAssertTrue(app.frame.contains(skip.frame), "「跳过本组」超出屏幕")
    }

    func testWorkoutCloseKeepsResumeCard() {        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        tap(button(A11y.Today.start))
        completeOneSet()

        tap(button(A11y.Workout.close))
        waitUntilGone(app.buttons.matching(identifier: A11y.Workout.completeSet).firstMatch)

        text(A11y.Today.title)
        button(A11y.Today.resume)
        XCTAssertTrue(app.staticTexts[A11y.Workout.summaryTitle].exists == false)
    }

    func testSettingsReminderTogglePersists() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        text(A11y.Today.title)
        tap(button(A11y.Today.settings))

        let reminderSwitch = toggle(A11y.Settings.reminderToggle)
        text(A11y.Settings.scheduledCount)
        XCTAssertTrue(app.staticTexts["通知权限"].exists)

        let before = reminderSwitch.value as? String
        tap(reminderSwitch)
        XCTAssertNotEqual(reminderSwitch.value as? String, before, "提醒开关点了没反应")

        tap(button(A11y.Settings.done))
        text(A11y.Today.title)
        tap(button(A11y.Today.settings))

        XCTAssertEqual(toggle(A11y.Settings.reminderToggle).value as? String, reminderSwitch.value as? String, "关掉再打开，开关状态没记住")
    }

    func testSettingsVoiceTogglePersists() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        text(A11y.Today.title)
        tap(button(A11y.Today.settings))

        let voiceSwitch = toggle(A11y.Settings.voiceToggle)
        let before = voiceSwitch.value as? String
        tap(voiceSwitch)
        XCTAssertNotEqual(voiceSwitch.value as? String, before, "语音开关点了没反应")
        let after = voiceSwitch.value as? String

        tap(button(A11y.Settings.done))
        text(A11y.Today.title)
        tap(button(A11y.Today.settings))

        XCTAssertEqual(toggle(A11y.Settings.voiceToggle).value as? String, after, "关掉再打开，语音开关没记住")
    }

    func testSettingsEraseAllLandsOnOnboarding() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1"])

        text(A11y.Today.title)
        tap(button(A11y.Today.settings))

        let erase = any(A11y.Settings.erase)
        scrollUntilHittable(erase)
        tap(erase)

        let confirm = app.sheets.buttons.matching(NSPredicate(format: "label == %@", "清空全部数据")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "清空确认没弹出来")
        tap(confirm)

        XCTAssertTrue(app.staticTexts["先认识一下"].waitForExistence(timeout: 20), "清空后没回到引导")
        button(A11y.Onboarding.next)
    }

    private func completeOneSet() {
        tap(button(A11y.Workout.completeSet))
        dismissRest()
    }

    private func skipOneSet() {
        tap(button(A11y.Workout.skipSet))
        tap(labeled("没时间"))
        dismissRest()
    }

    private func dismissRest(attempts: Int = 6) {
        let skipRest = app.buttons.matching(identifier: A11y.Workout.skipRest).firstMatch
        var remaining = attempts
        while skipRest.waitForExistence(timeout: 1), remaining > 0 {
            tap(skipRest)
            Thread.sleep(forTimeInterval: 0.5)
            remaining -= 1
        }
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 5) {
        var remaining = attempts
        while element.isHittable == false, remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
        XCTAssertTrue(element.isHittable, "滚动后仍然点不到目标元素")
    }

    func testImportedPlanFlagsSoreShoulder() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_PROFILE_INJURIES": "肩颈不适",
            "DK_IMPORT_PASTE": "周一 深蹲 4组×12次\n周三 俯卧撑 3组×10次\n周三 哑铃推举 3组×12次"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        text(A11y.Plan.title)

        let importButton = button(A11y.Plan.importPlan)
        scrollUntilHittable(importButton)
        tap(importButton)

        let parseButton = button(A11y.Import.parse)
        XCTAssertTrue(parseButton.waitForExistence(timeout: 10), "没打开导入页")
        tap(parseButton)

        XCTAssertTrue(
            button("\(A11y.Import.sorePart).shoulderNeck").waitForExistence(timeout: 20),
            "校对页没有出现不适部位选择"
        )
        XCTAssertTrue(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "会让肩颈明显吃力"))
                .firstMatch
                .waitForExistence(timeout: 10),
            "没标出会让肩颈吃力的动作"
        )
        XCTAssertTrue(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "可降阶为跪姿俯卧撑"))
                .firstMatch
                .exists,
            "俯卧撑没有给出降阶出口"
        )

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "review-safety"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testPlanDayRowOpensDayDetail() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_IMPORT_SAMPLE": "1"
        ])

        text(A11y.Today.title)
        tapTab("计划")
        text(A11y.Plan.title)

        tap(button("\(A11y.Plan.dayRow).1"))

        XCTAssertTrue(
            app.staticTexts["深蹲"].waitForExistence(timeout: 10),
            "点周一没打开当天详情"
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "plan-day-detail"
        shot.lifetime = .keepAlways
        add(shot)

        let firstItem = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", A11y.Plan.itemRow + "."))
            .firstMatch
        tap(firstItem)
        XCTAssertTrue(app.staticTexts["要点"].waitForExistence(timeout: 10), "点动作没进到动作详情")
        XCTAssertTrue(app.staticTexts["常见错误"].exists, "动作详情少了常见错误")

        let detailShot = XCTAttachment(screenshot: app.screenshot())
        detailShot.name = "exercise-detail"
        detailShot.lifetime = .keepAlways
        add(detailShot)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap(labeled("关闭"))
        waitUntilGone(app.staticTexts["深蹲"])
    }
}
