import XCTest

class DongKeUITestCase: XCTestCase {
    private(set) var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    @discardableResult
    func launchApp(_ environment: [String: String] = [:], file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DK_UI_TEST"] = "1"
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        self.app = app
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "App 没能进到前台", file: file, line: line)
        return app
    }

    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "目标元素不存在", file: file, line: line)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed, "元素一直没消失", file: file, line: line)
    }

    func any(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15), "没等到 \(identifier)", file: file, line: line)
        return element
    }

    func button(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15), "没等到按钮 \(identifier)", file: file, line: line)
        return element
    }

    func text(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.staticTexts.matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15), "没等到文本 \(identifier)", file: file, line: line)
        return element
    }

    func labeled(_ label: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15), "没等到按钮「\(label)」", file: file, line: line)
        return element
    }

    func toggle(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.switches.matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 15), "没等到开关 \(identifier)", file: file, line: line)
        return element
    }

    func tapTab(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        tap(labeled(title), file: file, line: line)
    }

    func dismissNotificationPromptIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["允许"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }
    }
}
