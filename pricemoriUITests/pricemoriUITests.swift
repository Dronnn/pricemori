import XCTest

final class PricemoriUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRecordNoChangeAndUndo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-reset-language"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Buckwheat"].waitForExistence(timeout: 5))

        app.buttons["No change · record today"].tap()
        XCTAssertTrue(app.staticTexts["Recorded today · No change"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.staticTexts["Recorded today · No change"].exists)

        app.buttons["Record a price"].tap()
        XCTAssertTrue(app.staticTexts["Record price"].waitForExistence(timeout: 5))
        let priceField = app.textFields["0"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        priceField.tap()
        priceField.typeText("330")
        app.buttons["Save observation"].tap()

        XCTAssertTrue(app.staticTexts["Price saved · Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["330"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AMD / kg"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.staticTexts["Price saved · Today"].exists)
    }

    @MainActor
    func testAddProductAndFirstPrice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-reset-language"]
        app.launch()

        app.buttons["+ Add"].tap()
        XCTAssertTrue(app.staticTexts["Add product"].waitForExistence(timeout: 5))

        let nameField = app.textFields["Buckwheat · Brand X"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Apples")
        app.buttons["Continue to price"].tap()

        XCTAssertTrue(app.staticTexts["First price"].waitForExistence(timeout: 5))
        let priceField = app.textFields["320"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        priceField.tap()
        priceField.typeText("100")

        let storeField = app.textFields["SAS"]
        XCTAssertTrue(storeField.waitForExistence(timeout: 5))
        storeField.tap()
        storeField.typeText("Test Market")

        let branchField = app.textFields["Komitas 12"]
        XCTAssertTrue(branchField.waitForExistence(timeout: 5))
        branchField.tap()
        branchField.typeText("Main")

        app.buttons["Save first price"].tap()
        XCTAssertTrue(app.staticTexts["Apples"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["First price saved"].waitForExistence(timeout: 5))
        app.buttons["Back to Journal"].tap()

        XCTAssertTrue(app.staticTexts["Apples"].waitForExistence(timeout: 5))
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "100 AMD / 1 kg")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
