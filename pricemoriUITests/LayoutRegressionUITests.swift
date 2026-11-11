import XCTest

@MainActor
final class LayoutRegressionUITests: XCTestCase {
    private func launch(largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-in-memory", "-seed-sample", "-skip-onboarding", "-reset-language"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-dark-mode"]
        }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        if !element.waitForExistence(timeout: 3) {
            for _ in 0..<12 where !element.exists {
                if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.frame.height > 100 && $0.isHittable }) {
                    scroll.swipeUp()
                } else {
                    app.swipeUp()
                }
            }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<12 where !element.isHittable {
            if let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.frame.height > 100 && $0.isHittable }) {
                let above = element.frame.midY < scroll.frame.midY
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.6))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.6 : 0.35))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            } else {
                if element.frame.midY < app.windows.firstMatch.frame.midY { app.swipeDown() }
                else { app.swipeUp() }
            }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let element: XCUIElement
        if label == "@product" {
            element = app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch
        } else if label.hasPrefix("~") {
            element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", String(label.dropFirst()))).firstMatch
        } else if app.buttons[label].exists {
            element = app.buttons.matching(identifier: label).allElementsBoundByIndex.last!
        } else {
            element = app.buttons.containing(.staticText, identifier: label).firstMatch
        }
        reveal(element, in: app)
        element.tap()
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let titles = [
            "settings": "Settings", "entry-defaults": "Entry defaults", "language": "Language",
            "backup": "Backup & export", "archived-products": "Archived products", "stores": "Stores",
            "store-detail": "Store", "store-edit": "Edit store", "store-add": "Add store",
            "archived-stores": "Archived stores", "support": "Support Pricemori", "add-product": "Add product",
            "product": "Buckwheat", "product-edit": "Edit product", "all-history": "All observations",
            "observation": "Observation", "correction": "Correct entry", "history": "History",
            "earlier-price": "Earlier price", "record-price": "Record price", "price-basis": "Price basis",
            "conditions": "Offer conditions", "currency": "Currency", "date-source": "Date & source",
            "store-picker": "Choose a store", "statistics": "Statistics", "chart-scope": "Change scope",
            "price-over-time": "Price over time", "chart-filters": "Chart filters", "chart-period": "Chart period",
            "store-comparison": "Compare stores", "comparison-conditional": "Compare stores",
            "comparison-exclusions": "Compare stores", "period-changes": "Period changes",
            "more-comparisons": "More comparisons", "package-unit": "Package vs unit", "store-histories": "Store histories",
            "record-large-text": "Record price", "basis-large-text": "Price basis", "conditions-large-text": "Offer conditions"
        ]
        if let title = titles[name] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "Expected destination: \(name). \(app.debugDescription)")
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "layout-16-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func captureRoutes(_ routes: [(String, [String])]) {
        let app = launch()
        for (index, route) in routes.enumerated() {
            if index > 0 { app.terminate(); app.launch() }
            for label in route.1 { tap(label, in: app) }
            capture(route.0, in: app)
        }
    }

    func testJournalSearchFiltersAndProductsHaveSeparateSpacing() {
        let app = launch()
        let search = app.buttons["Search name, brand or model"]
        let chips = [app.buttons["All"], app.buttons["Favorites"], app.buttons["Filter / sort"]]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(chips.map(\.frame.minY).min()! - search.frame.maxY, 15.5)
        let product = app.buttons.containing(.staticText, identifier: "Buckwheat · Brand X").firstMatch
        XCTAssertGreaterThanOrEqual(product.frame.minY - chips.map(\.frame.maxY).max()!, 23.5)
        for chip in chips { XCTAssertGreaterThanOrEqual(chip.frame.height, 44) }
        capture("journal-spacing", in: app)
    }

    func testSettingsAndStoreScreenLayouts() {
        captureRoutes([
            ("settings", ["Menu", "Settings"]),
            ("entry-defaults", ["Menu", "Settings", "Entry defaults"]),
            ("language", ["Menu", "Settings", "Language"]),
            ("backup", ["Menu", "Settings", "Backup & export"]),
            ("archived-products", ["Menu", "Settings", "Archived products"]),
            ("stores", ["Menu", "Stores"]),
            ("store-detail", ["Menu", "Stores", "SAS · Komitas 12"]),
            ("store-edit", ["Menu", "Stores", "SAS · Komitas 12", "Edit"]),
            ("store-add", ["Menu", "Stores", "+ Add"]),
            ("archived-stores", ["Menu", "Stores", "Archived stores"]),
            ("support", ["Support Pricemori"]),
            ("add-product", ["+ Add"])
        ])
    }

    func testProductHistoryAndRecordingScreenLayouts() {
        captureRoutes([
            ("product", ["@product"]),
            ("product-edit", ["@product", "Edit"]),
            ("all-history", ["@product", "all-product-observations"]),
            ("observation", ["@product", "all-product-observations", "~320 AMD"]),
            ("correction", ["@product", "all-product-observations", "~320 AMD", "Correct"]),
            ("history", ["@product", "History"]),
            ("earlier-price", ["@product", "History", "Record an earlier observation"]),
            ("record-price", ["@product", "Record a price"]),
            ("price-basis", ["@product", "Record a price", "~Per package"]),
            ("conditions", ["@product", "Record a price", "~Regular price"]),
            ("currency", ["@product", "Record a price", "AMD"]),
            ("date-source", ["@product", "Record a price", "~Seen on shelf"]),
            ("store-picker", ["@product", "Record a price", "SAS · Komitas 12"])
        ])
    }

    func testStatisticsScreenLayouts() {
        let stats = ["Menu", "Statistics & charts"]
        captureRoutes([
            ("statistics", stats),
            ("chart-scope", stats + ["Change scope"]),
            ("price-over-time", stats + ["Explore price history"]),
            ("chart-filters", stats + ["Explore price history", "Filter"]),
            ("chart-period", stats + ["Explore price history", "Filter", "~All time"]),
            ("store-comparison", stats + ["Where was it cheapest?"]),
            ("comparison-conditional", stats + ["Where was it cheapest?", "Conditional"]),
            ("comparison-exclusions", stats + ["Where was it cheapest?", "~Excluded"]),
            ("period-changes", stats + ["Which products changed most?"]),
            ("more-comparisons", stats + ["More ways to compare"]),
            ("package-unit", stats + ["More ways to compare", "Did the package get smaller?"]),
            ("store-histories", stats + ["More ways to compare", "Compare branch histories"])
        ])
    }

    func testLargeTextControlsWrapWithoutOverlapAndSaveStaysAboveKeyboard() {
        let app = launch(largeText: true)
        let chips = [app.buttons["All"], app.buttons["Favorites"], app.buttons["Filter / sort"]]
        XCTAssertTrue(chips[0].waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        for chip in chips {
            XCTAssertGreaterThanOrEqual(chip.frame.minX, window.minX)
            XCTAssertLessThanOrEqual(chip.frame.maxX, window.maxX)
        }
        for first in chips.indices {
            for second in chips.indices where second > first {
                XCTAssertFalse(chips[first].frame.intersects(chips[second].frame))
            }
        }
        capture("journal-large-text", in: app)
        tap("@product", in: app)
        tap("Record a price", in: app)
        capture("record-large-text", in: app)
        let price = app.textFields["0"]
        reveal(price, in: app)
        price.tap()
        price.typeText("330")
        let save = app.buttons["Save observation"]
        XCTAssertTrue(save.isHittable)
        XCTAssertLessThanOrEqual(save.frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("record-large-text-keyboard", in: app)
        tap("keyboard-done", in: app)
        tap("~Per package", in: app)
        capture("basis-large-text", in: app)
        tap("Cancel", in: app)
        let conditionRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Regular price")).firstMatch
        for _ in 0..<8 where conditionRow.frame.maxY > save.frame.minY - 12 {
            let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.frame.height > 100 && $0.isHittable })!
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertLessThanOrEqual(conditionRow.frame.maxY, save.frame.minY - 12)
        capture("record-large-text-before-conditions", in: app)
        tap("~Regular price", in: app)
        let choices = [app.buttons["Regular"], app.buttons["Card"], app.buttons["Multi-buy"]]
        XCTAssertTrue(choices[0].waitForExistence(timeout: 5))
        for choice in choices {
            XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
            XCTAssertLessThanOrEqual(choice.frame.maxX, window.maxX)
        }
        capture("conditions-large-text", in: app)
    }

    func testLargeTextOnboardingAndDonationContentRemainsReadable() {
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchArguments = ["-in-memory", "-reset-onboarding", "-reset-language",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let paragraphs = [
            "Write down what something cost at the shops you actually use.",
            "Over time you build your own history: dates, stores, and honest comparisons.",
            "No account, no cloud, no ads. Your journal stays on this device."
        ]
        for (index, text) in paragraphs.enumerated() {
            let body = app.staticTexts[text]
            XCTAssertTrue(body.waitForExistence(timeout: 5))
            let next = app.buttons[index == 2 ? "Get started" : "Next"]
            for _ in 0..<8 where body.frame.maxY > next.frame.minY - 12 {
                let scroll = app.scrollViews.allElementsBoundByIndex.last(where: \.isHittable)!
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
            }
            XCTAssertLessThanOrEqual(body.frame.maxY, next.frame.minY - 12)
            capture("onboarding-large-\(index)", in: app)
            next.tap()
        }
        app.terminate()
        let journal = launch(largeText: true)
        tap("Support Pricemori", in: journal)
        let first = journal.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Small tip")).firstMatch
        reveal(first, in: journal)
        XCTAssertGreaterThanOrEqual(first.frame.width, journal.windows.firstMatch.frame.width - 49)
        capture("support-large-text", in: journal)
        let last = journal.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Extraordinary tip")).firstMatch
        reveal(last, in: journal)
        XCTAssertGreaterThanOrEqual(last.frame.width, journal.windows.firstMatch.frame.width - 49)
        capture("support-large-text-bottom", in: journal)
    }
}
