import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCompletesOnFirstLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-reset-onboarding", "-reset-language"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Your own price journal"].waitForExistence(timeout: 5))

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Collect price statistics"].waitForExistence(timeout: 3))

        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Private and offline"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 3))
        app.buttons["Get started"].tap()

        XCTAssertTrue(app.staticTexts["Your price journal"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingCanBeReplayedFromSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-skip-onboarding", "-reset-language"]
        app.launch()

        app.buttons["Menu"].tap()
        app.buttons.containing(.staticText, identifier: "Settings").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        app.buttons.containing(.staticText, identifier: "Show onboarding").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Your own price journal"].waitForExistence(timeout: 5))

        app.buttons["Skip"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }
}
