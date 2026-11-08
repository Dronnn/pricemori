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
    func testUnknownPackageSizeSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["Record a price"].tap()

        let priceField = app.textFields["0"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        priceField.tap()
        priceField.typeText("300")

        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Per package")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Package amount *"].waitForExistence(timeout: 5))
        app.buttons["Package size unknown"].tap()
        app.buttons["Save package price only"].tap()

        app.buttons["Save observation"].tap()
        XCTAssertTrue(app.staticTexts["Price saved · Package size unknown"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Package size unknown · Regular"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCardConditionAndOfferDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["Record a price"].tap()

        let priceField = app.textFields["0"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        priceField.tap()
        priceField.typeText("280")

        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Regular price")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["When is this price available?"].waitForExistence(timeout: 5))
        app.buttons["Card"].tap()
        let labelField = app.textFields["SAS Club card required"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5))
        labelField.tap()
        labelField.typeText("Test card")
        app.buttons["Use this condition"].tap()

        app.buttons["Save observation"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Price saved")).firstMatch.waitForExistence(timeout: 5))

        app.swipeUp()
        let offers = app.buttons.containing(.staticText, identifier: "Conditional offers").firstMatch
        XCTAssertTrue(offers.waitForExistence(timeout: 5))
        offers.tap()
        XCTAssertTrue(app.staticTexts["Conditional offers"].waitForExistence(timeout: 5))

        let cardOffer = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Card offer")).firstMatch
        XCTAssertTrue(cardOffer.waitForExistence(timeout: 5))
        cardOffer.tap()
        XCTAssertTrue(app.staticTexts["Card-price detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Test card"].exists)
    }

    @MainActor
    func testDiscardDraftConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["Record a price"].tap()

        let priceField = app.textFields["0"]
        XCTAssertTrue(priceField.waitForExistence(timeout: 5))
        priceField.tap()
        priceField.typeText("330")
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["Discard changes?"].waitForExistence(timeout: 5))
        app.buttons["Keep editing"].tap()
        XCTAssertTrue(app.staticTexts["Record price"].waitForExistence(timeout: 5))

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Discard changes?"].waitForExistence(timeout: 5))
        app.buttons["Discard draft"].tap()
        XCTAssertTrue(app.staticTexts["Buckwheat"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchAndFavorites() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        app.buttons["Search name, brand or model"].tap()
        let search = app.textFields["Search name, brand or model"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("buck")
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.waitForExistence(timeout: 5))

        app.buttons["Clear search"].tap()
        search.tap()
        search.typeText("missing item")
        XCTAssertTrue(app.staticTexts["No matching products"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "missing item")).firstMatch.exists)
        app.buttons["Journal"].tap()

        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.buttons["All products"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Frequently tracked")).firstMatch.waitForExistence(timeout: 5))
        let remove = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Remove Buckwheat")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.staticTexts["No favorites yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVisibleTapTargetsMeet44Points() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample"]
        app.launch()

        assertTapTargets(in: app, context: "Journal")

        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Buckwheat"].waitForExistence(timeout: 5))
        assertTapTargets(in: app, context: "Product")
    }

    private func assertTapTargets(in app: XCUIApplication, context: String) {
        for button in app.buttons.allElementsBoundByIndex where button.isHittable {
            XCTAssertGreaterThanOrEqual(button.frame.height, 43.5, "Tap target too small on \(context): \(button.label) at \(button.frame)")
        }
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
