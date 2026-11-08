import XCTest

final class WorkflowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testArchiveAndRestoreProduct() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["Edit"].tap()
        app.buttons["Archive product…"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Archive"].tap()

        XCTAssertTrue(app.staticTexts["Journal"].waitForExistence(timeout: 5))
        app.buttons["Menu"].tap()
        app.buttons.containing(.staticText, identifier: "Settings").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Archived products").firstMatch.tap()
        XCTAssertTrue(app.buttons["Restore Buckwheat"].waitForExistence(timeout: 5))
        app.buttons["Restore Buckwheat"].tap()
        app.buttons["Back to Journal"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddEarlierObservationAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "History")).firstMatch.tap()
        app.buttons["Record an earlier observation"].tap()

        let priceField = app.textFields["0"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        priceField.tap()
        priceField.typeText("250")
        app.buttons["Save earlier price"].tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Earlier price added")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Earlier price added")).firstMatch.exists)
    }

    @MainActor
    func testDeleteObservationAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label == %@", "History")).firstMatch.tap()

        let observation = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "320 AMD / kg")).firstMatch
        XCTAssertTrue(observation.waitForExistence(timeout: 5))
        observation.tap()
        app.buttons["Delete observation…"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["Observation removed"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.staticTexts["Observation removed"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "320 AMD / kg")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddStore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons["Menu"].tap()
        app.buttons.containing(.staticText, identifier: "Stores").firstMatch.tap()
        app.buttons["+ Add"].tap()

        let nameField = app.textFields["SAS"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Corner Shop")

        let branchField = app.textFields["Komitas 12"]
        branchField.tap()
        branchField.typeText("Main Street")
        app.buttons["Use this store"].tap()

        XCTAssertTrue(app.staticTexts["Corner Shop · Main Street"].waitForExistence(timeout: 5))
    }
}
