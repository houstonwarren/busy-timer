import XCTest

// MARK: - Setup entry

final class SetupEntryTests: XCTestCase {
    /// Enter 75 reps, revisit the field, and dismiss the keyboard without losing the target.
    @MainActor
    func testRepEntryKeepsFocusAndValue() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        if let value = field.value as? String, let count = Int(value), count > 0 {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText("75")
        XCTAssertEqual(field.value as? String, "75")
        XCTAssertLessThanOrEqual(field.frame.maxY, app.staticTexts["YOUR PACE"].frame.minY)
        XCTAssertFalse(app.buttons["Done"].frame.intersects(app.buttons["START WORKOUT"].frame))

        let entry = XCTAttachment(screenshot: app.screenshot())
        entry.name = "closed-duo-rep-entry"
        entry.lifetime = .keepAlways
        add(entry)

        field.tap()
        XCTAssertEqual(field.value as? String, "75")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "75")
        XCTAssertTrue(app.buttons["START WORKOUT"].isEnabled)

        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["history"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["History"].exists)
    }
}
