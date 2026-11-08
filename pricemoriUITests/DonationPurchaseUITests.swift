import XCTest

final class DonationPurchaseUITests: XCTestCase {
    @MainActor
    func testDonationPurchaseShowsThankYou() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-reset-language"]
        app.launch()

        app.buttons["Support Pricemori"].tap()
        XCTAssertTrue(app.staticTexts["Support Pricemori"].waitForExistence(timeout: 5))

        let smallTip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "$2.99")).firstMatch
        XCTAssertTrue(smallTip.waitForExistence(timeout: 5))
        smallTip.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Donate")).firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Thank you."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your support helps keep Pricemori independent. Nothing is unlocked, and your journal stays exactly as it is."].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Journal"].waitForExistence(timeout: 5))
    }
}
