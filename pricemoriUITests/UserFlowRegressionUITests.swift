import XCTest

@MainActor
final class UserFlowRegressionUITests: XCTestCase {
    private func launch(persistent: Bool = false, seeded: Bool = false, dark: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skip-onboarding", "-reset-language"]
        if !persistent { app.launchArguments.append("-in-memory") }
        if seeded { app.launchArguments.append("-seed-sample") }
        if dark { app.launchArguments.append("-dark-mode") }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 where !element.isHittable {
            if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.frame.height > 100 && $0.isHittable }) { scroll.swipeUp() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func createPackageProduct(_ name: String, in app: XCUIApplication) {
        if app.buttons["+ Add"].exists { app.buttons["+ Add"].tap() }
        else { app.buttons["Add your first product"].tap() }
        let field = app.textFields["Buckwheat · Brand X"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["Continue to price"].tap()
        app.textFields["320"].tap()
        app.textFields["320"].typeText("111")
        app.textFields["SAS"].tap()
        app.textFields["SAS"].typeText("Flow shop")
        app.textFields["Komitas 12"].tap()
        app.textFields["Komitas 12"].typeText("Centre")
        app.buttons["Save first price"].tap()
        XCTAssertTrue(app.staticTexts["First price saved"].waitForExistence(timeout: 5))
    }

    private func addSecondPackagePrice(in app: XCUIApplication) {
        let noChange = app.buttons["No change · record today"]
        reveal(noChange, in: app)
        noChange.tap()
        XCTAssertTrue(app.staticTexts["Recorded today · No change"].waitForExistence(timeout: 5))
        let record = app.buttons["Record a price"]
        reveal(record, in: app)
        record.tap()
        let price = app.textFields["0"]
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        price.tap()
        price.typeText("444")
        XCTAssertEqual(price.value as? String, "444")
        let saveCapture = XCTAttachment(screenshot: app.screenshot())
        saveCapture.name = "package-entry-keyboard-save"
        saveCapture.lifetime = .keepAlways
        add(saveCapture)
        XCTAssertTrue(app.buttons["Save observation"].isHittable, app.debugDescription)
        app.buttons["Save observation"].tap()
        XCTAssertTrue(app.staticTexts["444"].waitForExistence(timeout: 5))
    }

    func testPackageOnlyPricesSurviveRelaunchAndStayVisibleInChartsAndHistory() {
        let app = launch(persistent: true)
        let name = "Persistent flow \(UUID().uuidString.prefix(8))"
        createPackageProduct(name, in: app)
        addSecondPackagePrice(in: app)
        app.terminate()
        app.launch()
        let row = app.buttons.containing(.staticText, identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["444"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No unit price to chart"].exists)
        let count = app.staticTexts["3 observations · No estimates between dates"]
        reveal(count, in: app)
        let productCapture = XCTAttachment(screenshot: app.screenshot())
        productCapture.name = "persistent-package-price-chart"
        productCapture.lifetime = .keepAlways
        add(productCapture)
        let all = app.buttons["all-product-observations"]
        reveal(all, in: app)
        all.tap()
        XCTAssertTrue(app.staticTexts["All observations"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AMD / package")).count, 3)
        app.buttons["Back"].tap()
        let stats = app.buttons["Statistics"]
        reveal(stats, in: app)
        stats.tap()
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AMD / package"].exists)
        XCTAssertFalse(app.staticTexts["No regular observations at this branch yet."].exists)
        let more = app.buttons["More ways to compare"]
        reveal(more, in: app)
        more.tap()
        XCTAssertTrue(app.staticTexts["Regular · All time · AMD / package"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No recorded range yet."].exists)
        let package = app.buttons.containing(.staticText, identifier: "Did the package get smaller?").firstMatch
        reveal(package, in: app)
        package.tap()
        XCTAssertTrue(app.staticTexts["AMD / package"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No unit price to chart"].exists)
        app.buttons["Back"].tap()
        app.buttons["Charts"].tap()
        let chart = app.buttons["Explore price history"]
        reveal(chart, in: app)
        chart.tap()
        XCTAssertTrue(app.staticTexts["Price over time"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AMD / package"].exists)
        let list = app.buttons["View observation list"]
        reveal(list, in: app)
        list.tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AMD / package")).count, 3)
        app.buttons["Back"].tap()
        app.buttons["Back"].tap()
        app.buttons["Back"].tap()
        app.buttons["Journal"].tap()
        row.tap()
        deleteCurrentProduct(in: app)
        XCTAssertFalse(app.buttons.containing(.staticText, identifier: name).firstMatch.exists)
    }

    private func deleteCurrentProduct(in app: XCUIApplication) {
        app.buttons["Edit"].tap()
        let delete = app.buttons["Delete product…"]
        reveal(delete, in: app)
        delete.tap()
        app.alerts.buttons["Delete product"].tap()
    }

    func testArchiveCanInspectRestoreAndReturnToJournalWithoutLosingPrices() {
        let app = launch(dark: true)
        createPackageProduct("Archived flow", in: app)
        app.buttons["Edit"].tap()
        let archive = app.buttons["Archive product…"]
        reveal(archive, in: app)
        archive.tap()
        app.alerts.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["No active products"].waitForExistence(timeout: 5))
        app.buttons["Archived products"].tap()
        let archiveCapture = XCTAttachment(screenshot: app.screenshot())
        archiveCapture.name = "archive-dark-with-restore"
        archiveCapture.lifetime = .keepAlways
        add(archiveCapture)
        app.buttons.containing(.staticText, identifier: "Archived flow").firstMatch.tap()
        XCTAssertTrue(app.buttons["Restore product"].waitForExistence(timeout: 5))
        let all = app.buttons["all-product-observations"]
        reveal(all, in: app)
        all.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "111 AMD / package")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        app.buttons["Restore product"].tap()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["No archived products."].waitForExistence(timeout: 5))
        app.buttons["Back to Journal"].tap()
        app.buttons.containing(.staticText, identifier: "Archived flow").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["111"].waitForExistence(timeout: 5))
        deleteCurrentProduct(in: app)
        XCTAssertTrue(app.staticTexts["No active products"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["+ Add"].exists)
        app.buttons["Menu"].tap()
        app.buttons.containing(.staticText, identifier: "Stores").firstMatch.tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Flow shop · Centre").firstMatch.waitForExistence(timeout: 5))
    }

    func testJournalSwipesAndLongPressExposeUsefulActions() {
        let app = launch(seeded: true)
        let row = app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch
        row.swipeLeft()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        app.alerts.buttons["Keep tracking"].tap()
        row.swipeRight()
        XCTAssertTrue(app.buttons["Record a price"].waitForExistence(timeout: 5))
        app.buttons["Record a price"].tap()
        XCTAssertTrue(app.buttons["Save observation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 5))
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["All observations"].waitForExistence(timeout: 5))
    }

    func testCorrectingWrongBranchKeepsRecordVisibleInAllHistory() {
        let app = launch(seeded: true)
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        let all = app.buttons["all-product-observations"]
        reveal(all, in: app)
        all.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "320 AMD / 1 kg")).firstMatch.tap()
        app.buttons["Correct"].tap()
        let location = app.buttons.containing(.staticText, identifier: "Product and branch").firstMatch
        reveal(location, in: app)
        location.tap()
        let branch = app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch
        reveal(branch, in: app)
        branch.tap()
        app.buttons["Use this location"].tap()
        app.buttons["Save correction"].tap()
        XCTAssertTrue(app.staticTexts["Nor Zovq · Abovyan"].waitForExistence(timeout: 5))
        let chart = app.buttons["Chart this history"]
        reveal(chart, in: app)
        chart.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Nor Zovq · Abovyan · Regular")).firstMatch.waitForExistence(timeout: 5))
    }

    func testEmptyBranchAfterCorrectionStillExposesAllProductHistory() {
        let app = launch(seeded: true)
        app.buttons["Filter / sort"].tap()
        app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.tap()
        app.buttons["Apply filters"].tap()
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        let all = app.buttons["all-product-observations"]
        reveal(all, in: app)
        all.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "300 AMD / 900 g")).firstMatch.tap()
        app.buttons["Correct"].tap()
        let location = app.buttons.containing(.staticText, identifier: "Product and branch").firstMatch
        reveal(location, in: app)
        location.tap()
        let sas = app.buttons.containing(.staticText, identifier: "SAS · Komitas 12").firstMatch
        reveal(sas, in: app)
        sas.tap()
        app.buttons["Use this location"].tap()
        app.buttons["Save correction"].tap()
        app.buttons["History"].tap()
        app.buttons["Back"].tap()
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Record first price"].exists)
        XCTAssertTrue(app.staticTexts["No observations match this scope. Your saved prices are available in All observations."].exists)
        all.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "300 AMD / 900 g")).firstMatch.exists)
    }

    func testSwipeRecordingShowsTheBranchActuallySavedAndCanUndo() {
        let app = launch(seeded: true)
        app.buttons["Filter / sort"].tap()
        app.buttons.containing(.staticText, identifier: "SAS · Komitas 12").firstMatch.tap()
        app.buttons["Apply filters"].tap()
        let row = app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch
        row.swipeRight()
        app.buttons["Record a price"].tap()
        let price = app.textFields["0"]
        price.tap()
        price.typeText("330")
        XCTAssertTrue(app.buttons["keyboard-done"].waitForExistence(timeout: 5))
        app.buttons["keyboard-done"].tap()
        app.buttons.containing(.staticText, identifier: "SAS · Komitas 12").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Nor Zovq · Abovyan").firstMatch.tap()
        app.buttons["Save observation"].tap()
        XCTAssertTrue(app.staticTexts["Price saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nor Zovq · Abovyan"].exists)
        XCTAssertTrue(app.staticTexts["330"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(app.staticTexts["330"].exists)
    }

    func testRecordingFromConditionalChartPreservesTheOfferScope() {
        let app = launch(seeded: true)
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        let all = app.buttons["all-product-observations"]
        reveal(all, in: app)
        all.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "280 AMD / 1 kg", "SAS Club")).firstMatch.tap()
        let chart = app.buttons["Chart this history"]
        reveal(chart, in: app)
        chart.tap()
        let record = app.buttons["Record another observation"]
        reveal(record, in: app)
        record.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "SAS Club")).firstMatch.waitForExistence(timeout: 5))
        app.textFields["0"].tap()
        app.textFields["0"].typeText("275")
        app.buttons["Save observation"].tap()
        XCTAssertTrue(app.staticTexts["Price saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SAS Club")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["275"].exists)
        let list = app.buttons["View observation list"]
        reveal(list, in: app)
        list.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "275 AMD / kg")).firstMatch.tap()
        let delete = app.buttons["Delete observation…"]
        reveal(delete, in: app)
        delete.tap()
        app.alerts.buttons["Delete"].tap()
        app.buttons["Undo"].tap()
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Price saved"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.staticTexts["More data needed"].waitForExistence(timeout: 5))
    }

    func testEarlierEntryDeletionAndBothUndoPathsResolveTheCurrentRecord() {
        let app = launch(seeded: true)
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["History"].tap()
        app.buttons["Record an earlier observation"].tap()
        app.textFields["0"].tap()
        app.textFields["0"].typeText("250")
        app.buttons["Save earlier price"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "250 AMD / kg")).firstMatch
        reveal(row, in: app)
        row.tap()
        let delete = app.buttons["Delete observation…"]
        reveal(delete, in: app)
        delete.tap()
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Observation removed"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Undo").count, 1)
        app.buttons["Undo"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertFalse(row.exists)
    }

    func testProductDeletionCanBeCancelledAndEditingAsksBeforeDiscarding() {
        let app = launch(seeded: true)
        app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch.tap()
        app.buttons["Edit"].tap()
        let name = app.textFields["Buckwheat"]
        name.tap()
        name.typeText(" changed")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.alerts.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.alerts.buttons["Keep editing"].tap()
        if app.buttons["keyboard-done"].exists { app.buttons["keyboard-done"].tap() }
        let delete = app.buttons["Delete product…"]
        reveal(delete, in: app)
        delete.tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Save product"].exists)
        app.buttons["Cancel"].tap()
        app.alerts.buttons["Discard draft"].tap()
        XCTAssertTrue(app.staticTexts["Buckwheat"].exists)
    }
}
