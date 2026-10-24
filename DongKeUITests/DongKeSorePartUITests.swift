import XCTest

final class DongKeSorePartUITests: DongKeUITestCase {
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

    func testDayDetailListsReliefExercisesForSorePart() {
        launchApp([
            "DK_COMPLETE_ONBOARDING": "1",
            "DK_PROFILE_INJURIES": "肩颈不适",
            "DK_PREVIEW": "plan"
        ])

        tap(button("\(A11y.Plan.dayRow).1"))

        let relief = app.descendants(matching: .any)[A11y.Import.safetyRelief]
        XCTAssertTrue(relief.waitForExistence(timeout: 10), "填了肩颈不适，详情页却没给有帮助的动作")
        XCTAssertTrue(
            app.staticTexts["下巴回收、肩胛后缩、靠墙天使、颈部等长"].exists,
            "推荐的不是那四条肩颈康复动作"
        )
    }

    func testDayDetailHidesReliefWithoutInjuries() {
        launchApp(["DK_COMPLETE_ONBOARDING": "1", "DK_PREVIEW": "plan"])

        tap(button("\(A11y.Plan.dayRow).1"))
        XCTAssertTrue(app.staticTexts["深蹲"].waitForExistence(timeout: 10), "没打开当天详情")

        XCTAssertFalse(
            app.descendants(matching: .any)[A11y.Import.safetyRelief].waitForExistence(timeout: 3),
            "没填伤病也显示了推荐"
        )
    }
}
