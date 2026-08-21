//
//  HabitUITests.swift
//  HabitUITests
//
//  Created by Liam Byrne on 8/8/26.
//

import XCTest

final class HabitUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    /// Regression test for a real bug: two sibling interactive controls
    /// (the habit name and the check-off button) sharing one `HStack`, in a
    /// `ForEach`/`LazyVStack`/`ScrollView` row, silently failed to register
    /// *any* click on macOS without an explicit `.contentShape(Rectangle())`
    /// on each. This drives a real accessibility click on the first
    /// check-off button found, exactly as a user would, and requires it to
    /// exist and be clickable. It does not verify the resulting data change
    /// (that needs a separate, external check against the persisted
    /// store) — it exists to catch a future regression where the click
    /// stops registering at all.
    @MainActor
    func testCheckOffButtonIsClickable() throws {
        let app = XCUIApplication()
        app.launch()

        let predicate = NSPredicate(format: "identifier BEGINSWITH 'checkCircle-'")
        let checkCircle = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(checkCircle.waitForExistence(timeout: 15), "no check-off button found via accessibility")
        checkCircle.click()
    }
}
