import XCTest

final class LocalizationProbeUITests: XCTestCase {
    @MainActor
    func testGermanScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-skip-onboarding", "-appLanguage", "de"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Tagebuch"].waitForExistence(timeout: 5))
        attach(app, name: "journal-de")

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Buckwheat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Preis erfassen"].exists)
        attach(app, name: "product-de")

        app.buttons["Preis erfassen"].tap()
        XCTAssertTrue(app.staticTexts["Preis für diese Packung"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Beobachtung speichern"].exists)
        attach(app, name: "record-de")
        app.buttons["Abbrechen"].tap()

        XCTAssertTrue(app.staticTexts["Buckwheat"].waitForExistence(timeout: 5))
        app.buttons["Tagebuch"].tap()
        XCTAssertTrue(app.staticTexts["Tagebuch"].waitForExistence(timeout: 5))

        app.buttons["Menü"].tap()
        app.buttons.containing(.staticText, identifier: "Einstellungen").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Einstellungen"].waitForExistence(timeout: 5))
        attach(app, name: "settings-de")
        app.buttons["Tagebuch"].tap()

        app.buttons["Pricemori unterstützen"].tap()
        XCTAssertTrue(app.staticTexts["Betrag wählen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Halte Pricemori")).firstMatch.exists)
        attach(app, name: "donation-de")
        app.buttons["Schließen"].tap()
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
