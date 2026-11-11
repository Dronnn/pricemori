import XCTest

@MainActor
final class ReleaseRegressionUITests: XCTestCase {
    private func launch(_ extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-skip-onboarding", "-reset-language"] + extraArguments
        app.launch()
        return app
    }

    func testLargeTextDarkRecordingRemainsUsable() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-dark-mode"])
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        let record = app.buttons["Record a price"]
        for _ in 0..<5 where !record.isHittable { app.swipeUp() }
        XCTAssertTrue(record.isHittable)
        let product = XCTAttachment(screenshot: app.screenshot())
        product.name = "product-dark-accessibility-text"
        product.lifetime = .keepAlways
        add(product)
        record.tap()
        XCTAssertTrue(app.buttons["Save observation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Save observation"].isHittable)
        XCTAssertGreaterThanOrEqual(app.buttons["Save observation"].frame.height, 44)
        XCTAssertLessThanOrEqual(app.buttons["Save observation"].frame.maxY, app.windows.firstMatch.frame.maxY, "Save must fit fully inside the visible window")
        let cancel = app.buttons["Cancel"]
        let title = app.staticTexts["Record price"]
        XCTAssertTrue(cancel.exists && title.exists)
        XCTAssertFalse(cancel.frame.intersects(title.frame), "Header title must not overlap Cancel at accessibility text sizes")
        let recording = XCTAttachment(screenshot: app.screenshot())
        recording.name = "record-dark-accessibility-text"
        recording.lifetime = .keepAlways
        add(recording)
    }

    func testStoreOriginRemainsTheRecordingBranch() {
        let app = launch()
        app.buttons["Menu"].tap()
        app.buttons.containing(.staticText, identifier: "Stores").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nor Zovq · Abovyan"].waitForExistence(timeout: 5))
        app.buttons["Record a price"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.waitForExistence(timeout: 5))
    }

    func testJournalBranchFilterRemainsTheRecordingBranch() {
        let app = launch()
        app.buttons["Filter / sort"].tap()
        app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.tap()
        app.buttons["Apply filters"].tap()
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nor Zovq · Abovyan"].waitForExistence(timeout: 5))
        app.buttons["Record a price"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.waitForExistence(timeout: 5))
    }

    func testSwitchingBranchPreservesTheEnteredPriceBasis() {
        let app = launch()
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["Record a price"].tap()
        let price = app.textFields["0"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        price.tap()
        price.typeText("330")
        XCTAssertTrue(app.buttons["keyboard-done"].waitForExistence(timeout: 5))
        app.buttons["keyboard-done"].tap()
        app.buttons.containing(.staticText, identifier: "SAS · Komitas 12").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.tap()
        XCTAssertEqual(price.value as? String, "330")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Per package · 1 kg")).firstMatch.exists)
        app.buttons["Save observation"].tap()
        XCTAssertTrue(app.staticTexts["Nor Zovq · Abovyan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["330"].waitForExistence(timeout: 5))
    }

    func testCorrectionCanChangeCurrencyAndOfferEligibility() {
        let app = launch()
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "History")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "320 AMD / kg")).firstMatch.tap()
        app.buttons["Correct"].tap()
        app.buttons.containing(.staticText, identifier: "Currency").firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch.tap()
        app.buttons["Use USD"].tap()
        let condition = app.buttons.containing(.staticText, identifier: "Regular price").firstMatch
        for _ in 0..<3 where !condition.isHittable { app.swipeUp() }
        condition.tap()
        app.buttons["Card"].tap()
        app.textFields["SAS Club card required"].tap()
        app.textFields["SAS Club card required"].typeText("Correction Club")
        app.buttons["Use this condition"].tap()
        app.buttons["Save correction"].tap()
        XCTAssertTrue(app.staticTexts["USD / kg"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Correction Club")).firstMatch.exists)
        app.buttons["History"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "300 AMD / kg")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Chart"].tap()
        XCTAssertTrue(app.staticTexts["AMD / kg"].waitForExistence(timeout: 5))
    }

    func testEarlierPriceCancelPreservesChangedDraft() {
        let app = launch()
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "History")).firstMatch.tap()
        app.buttons["Record an earlier observation"].tap()
        let price = app.textFields["0"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        price.tap()
        price.typeText("250")
        XCTAssertTrue(app.buttons["keyboard-done"].waitForExistence(timeout: 5))
        app.buttons["keyboard-done"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Keep editing"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Keep editing"].tap()
        XCTAssertEqual(price.value as? String, "250")
        app.buttons["Cancel"].tap()
        app.buttons["Discard draft"].tap()
        XCTAssertTrue(app.buttons["Record an earlier observation"].waitForExistence(timeout: 5))
    }

    func testFirstSaveUndoRemovesOnlyTheObservation() {
        let app = launch()
        app.buttons["+ Add"].tap()
        app.textFields["Buckwheat · Brand X"].tap()
        app.textFields["Buckwheat · Brand X"].typeText("Undo product")
        app.buttons["Continue to price"].tap()
        app.textFields["320"].tap()
        app.textFields["320"].typeText("100")
        app.textFields["SAS"].tap()
        app.textFields["SAS"].typeText("Test shop")
        app.textFields["Komitas 12"].tap()
        app.textFields["Komitas 12"].typeText("Centre")
        app.buttons["Save first price"].tap()
        XCTAssertTrue(app.staticTexts["First price saved"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Record first price"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Undo product"].exists)
    }
}
