import Foundation
import Testing
@testable import pricemori

@MainActor
struct PriceRegressionTests {
    @Test func correctionChangesOfferFieldsWithoutReplacingTheRecord() {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "First")
        let original = observation(300, product: product, store: store)
        let id = original.id
        let created = original.createdAt
        var draft = ObservationDraft()
        draft.priceText = "12"
        draft.currencyCode = "USD"
        draft.sizeKnown = true
        draft.quantityText = "1"
        draft.condition = .multiBuy
        draft.multiBuyMinimum = 3
        draft.note = "Receipt correction"
        #expect(draft.applyCorrection(to: original))
        #expect(original.id == id && original.createdAt == created)
        #expect(original.store?.id == store.id && original.product?.id == product.id)
        #expect(original.currencyCode == "USD" && original.price == 12)
        #expect(original.condition == .multiBuy && original.multiBuyMinimum == 3)
        #expect(original.unitPrice == 4 && original.note == draft.note)
        draft.condition = .card
        draft.conditionLabel = "Club"
        draft.conditionEndDate = Date(timeIntervalSince1970: 2000)
        #expect(draft.applyCorrection(to: original))
        #expect(original.multiBuyMinimum == 1)
        #expect(original.conditionLabel == "Club" && original.conditionEndDate == draft.conditionEndDate)
        draft.priceText = Format.inputText(Decimal(string: "0.001")!)
        #expect(!draft.applyCorrection(to: original))
        #expect(original.price == 12)
    }

    @Test func branchSuggestionsNeverReplaceAnEditedPriceDraft() {
        let product = Product(name: "Rice")
        let firstStore = StoreLocation(name: "Shop", branch: "First")
        let nextStore = StoreLocation(name: "Shop", branch: "Next")
        let template = observation(300, currency: "AMD", product: product, store: firstStore)
        let next = observation(2, unit: .gram, quantity: 900, currency: "USD", product: product, store: nextStore)
        var draft = ObservationDraft()
        draft.applyTemplate(from: template)
        let baseline = draft
        draft.priceText = "330"
        draft.observedAt = Date(timeIntervalSince1970: 1000)
        draft.source = .paid
        draft.quantityText = "800"
        draft.unit = .gram
        let edited = draft
        draft.suggestTemplate(from: next, ifUneditedSince: baseline, at: nextStore)
        #expect(draft == edited)
        draft.suggestTemplate(from: template, ifUneditedSince: baseline, at: firstStore)
        #expect(draft == edited)
    }

    @Test func branchSuggestionsDoNotBorrowAnotherStoresEligibility() {
        let first = StoreLocation(name: "Shop", branch: "First")
        let other = StoreLocation(name: "Shop", branch: "Other")
        let template = observation(900, condition: .multiBuy, minimum: 3, product: Product(name: "Rice"), store: first)
        var draft = ObservationDraft()
        let baseline = draft
        draft.suggestTemplate(from: template, ifUneditedSince: baseline, at: other)
        #expect(draft.condition == .regular)
        #expect(draft.multiBuyMinimum == 1)
        #expect(draft.observedAt == baseline.observedAt)
        #expect(draft.quantityText == Format.inputText(1))
    }

    @Test func unknownLatestSizeDoesNotMixBranchUnits() {
        let product = Product(name: "Cleaner")
        let massStore = StoreLocation(name: "Shop", branch: "Mass")
        let volumeStore = StoreLocation(name: "Shop", branch: "Volume")
        let unknownStore = StoreLocation(name: "Shop", branch: "Unknown")
        let volume = observation(200, unit: .liter, product: product, store: volumeStore)
        let mass = observation(300, day: 1, product: product, store: massStore)
        let unknown = observation(350, day: 2, unit: nil, quantity: nil, product: product, store: unknownStore)
        product.observations = [volume, mass, unknown]
        let reference = PriceMath.crossStoreReference(for: product)
        #expect(reference?.id == mass.id)
        #expect(PriceMath.series(for: product, store: massStore, reference: reference).map(\.id) == [mass.id])
        #expect(PriceMath.series(for: product, store: volumeStore, reference: reference).isEmpty)
        #expect(PriceMath.latestPerStore(for: product).filter { item in
            reference.map { PriceMath.comparable(item.observation, $0) } ?? false
        }.map(\.store.id) == [massStore.id])
    }

    @Test func crossStoreReferenceKeepsCurrencyAndArchivesSeparate() {
        let product = Product(name: "Rice")
        let active = StoreLocation(name: "Shop", branch: "Active")
        let archived = StoreLocation(name: "Shop", branch: "Archived")
        archived.isArchived = true
        let dram = observation(300, product: product, store: active)
        let dollarUnknown = observation(1, day: 1, unit: nil, quantity: nil, currency: "USD", product: product, store: active)
        let oldBranch = observation(350, day: 2, product: product, store: archived)
        product.observations = [dram, dollarUnknown, oldBranch]
        #expect(PriceMath.crossStoreReference(for: product) == nil)
        #expect(PriceMath.crossStoreReference(for: product, currency: "AMD")?.id == dram.id)
    }

    private func observation(
        _ price: Decimal,
        day: Int = 0,
        unit: MeasurementUnit? = .kilogram,
        quantity: Decimal? = 1,
        currency: String = "AMD",
        condition: ObservationCondition = .regular,
        label: String = "",
        minimum: Int = 1,
        product: Product,
        store: StoreLocation
    ) -> PriceObservation {
        PriceObservation(
            price: price,
            currencyCode: currency,
            observedAt: Date(timeIntervalSince1970: Double(day) * 86_400),
            packageQuantity: quantity,
            packageUnit: unit,
            sizeKnown: quantity != nil,
            condition: condition,
            conditionLabel: label,
            multiBuyMinimum: minimum,
            product: product,
            store: store
        )
    }

    @Test func pairPricesKeepThePairAsTheirBaseUnit() {
        let product = Product(name: "Sneakers")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let first = observation(20_000, unit: .pair, product: product, store: store)
        let next = observation(22_000, day: 1, unit: .pair, product: product, store: store)
        #expect(first.unitPrice == 20_000)
        #expect(first.baseUnitSymbol == MeasurementUnit.pair.symbol)
        #expect(PriceMath.change(current: next, previous: first)?.amount == 2_000)
    }

    @Test func newDraftDoesNotInventPackageSize() {
        var draft = ObservationDraft()
        draft.priceText = "300"
        #expect(!draft.sizeKnown)
        #expect(draft.quantityText.isEmpty)
        #expect(draft.unitPricePreview == nil)
        let saved = draft.makeObservation(product: Product(name: "Bread"), store: StoreLocation(name: "Shop", branch: "Centre"))
        #expect(saved?.price == 300)
        #expect(saved?.packageQuantity == nil)
        #expect(saved?.packageUnit == nil)
        #expect(saved?.unitPrice == nil)
    }

    @Test func priceMustRemainPositiveAtCurrencyPrecision() {
        var draft = ObservationDraft()
        draft.currencyCode = "USD"
        draft.priceText = Format.inputText(Decimal(string: "0.001")!)
        #expect(!draft.hasValidPrice)
        #expect(draft.makeObservation(product: Product(name: "Bread"), store: StoreLocation(name: "Shop", branch: "Centre")) == nil)
        draft.priceText = Format.inputText(Decimal(string: "0.01")!)
        #expect(draft.hasValidPrice)
    }

    @Test func explicitlyEnteredPackageSizeIsPreservedOnSave() {
        var draft = ObservationDraft()
        draft.priceText = "300"
        draft.sizeKnown = true
        draft.quantityText = "900"
        draft.unit = .gram
        let saved = draft.makeObservation(product: Product(name: "Rice"), store: StoreLocation(name: "Shop", branch: "Centre"))
        #expect(saved?.sizeKnown == true)
        #expect(saved?.packageQuantity == 900)
        #expect(saved?.packageUnit == .gram)
        #expect(saved?.unitPrice == draft.unitPricePreview)
        #expect(saved?.unitPrice != nil)
    }

    @Test func existingPackageTemplateRemainsKnownInARepeatDraft() {
        let existing = observation(300, unit: .liter, quantity: 2, product: Product(name: "Milk"), store: StoreLocation(name: "Shop", branch: "Centre"))
        var draft = ObservationDraft()
        draft.applyTemplate(from: existing)
        draft.priceText = "330"
        #expect(draft.sizeKnown)
        #expect(draft.quantity == 2)
        #expect(draft.unit == .liter)
        #expect(draft.unitPricePreview == 165)
    }

    @Test func multibuyLineShowsTheTotalForAllPackages() {
        let offer = observation(900, condition: .multiBuy, minimum: 3, product: Product(name: "Rice"), store: StoreLocation(name: "Shop", branch: "Centre"))
        #expect(offer.effectivePackagePrice == 300)
        #expect(offer.unitPrice == 300)
        #expect(offer.packagePriceLine.hasPrefix("\(Format.money(900, currency: "AMD")) AMD / 3 × "))
    }

    @Test func parserRejectsPartialAndMalformedNumbers() {
        let locale = Locale(identifier: "en_US")
        for input in ["12oops", "12.3.4", "1e3", "1,2", "NaN", "--2", "2\n3", ""] {
            #expect(Format.decimal(from: input, locale: locale) == nil)
        }
        #expect(Format.decimal(from: " 1,234.50 ", locale: locale) == Decimal(string: "1234.50"))
        #expect(Format.decimal(from: "1,000", locale: locale) == 1_000)
        #expect(Format.decimal(from: "1,234", locale: locale) == 1_234)
        #expect(Format.decimal(from: ".5", locale: locale) == Decimal(string: "0.5"))
    }

    @Test func parserHonorsLocaleDecimalAndGroupingSeparators() {
        #expect(Format.decimal(from: "1.234,50", locale: Locale(identifier: "de_DE")) == Decimal(string: "1234.50"))
        #expect(Format.decimal(from: "1,234", locale: Locale(identifier: "de_DE")) == Decimal(string: "1.234"))
        #expect(Format.decimal(from: "1 234,50", locale: Locale(identifier: "fr_FR")) == Decimal(string: "1234.50"))
        #expect(Format.decimal(from: "12.34,50", locale: Locale(identifier: "de_DE")) == nil)
        let value = Decimal(string: "1234.567")!
        #expect(Format.decimal(from: Format.inputText(value)) == value)
    }

    @Test func unitSeriesCannotJoinDifferentDimensionsOrCurrencies() {
        let product = Product(name: "Cleaner")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let mass = observation(300, unit: .kilogram, product: product, store: store)
        let volume = observation(400, day: 1, unit: .liter, product: product, store: store)
        let foreign = observation(2, day: 2, unit: .liter, currency: "USD", product: product, store: store)
        let latest = observation(450, day: 3, unit: .liter, product: product, store: store)
        product.observations = [mass, volume, foreign, latest]
        #expect(PriceMath.series(for: product, store: store).map(\.id) == [volume.id, latest.id])
    }

    @Test func countUnitsStaySeparateEvenWithinTheCountDimension() {
        let product = Product(name: "Bread")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let item = observation(300, unit: .item, product: product, store: store)
        let loaf = observation(320, day: 1, unit: .loaf, product: product, store: store)
        product.observations = [item, loaf]
        #expect(!PriceMath.comparable(item, loaf))
        #expect(PriceMath.series(for: product, store: store).map(\.id) == [loaf.id])
    }

    @Test func cardAndMultibuyEligibilityScopesStaySeparate() {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let club = observation(300, condition: .card, label: "Club", product: product, store: store)
        let premium = observation(280, day: 1, condition: .card, label: "Premium", product: product, store: store)
        let clubAgain = observation(310, day: 2, condition: .card, label: " club\n", product: product, store: store)
        let buyTwo = observation(600, condition: .multiBuy, minimum: 2, product: product, store: store)
        let buySix = observation(1_500, day: 1, condition: .multiBuy, minimum: 6, product: product, store: store)
        product.observations = [club, premium, clubAgain, buyTwo, buySix]
        #expect(PriceMath.series(for: product, store: store, condition: .card).map(\.id) == [club.id, clubAgain.id])
        #expect(!PriceMath.comparable(buyTwo, buySix))
        #expect(PriceMath.series(for: product, store: store, condition: .multiBuy).map(\.id) == [buySix.id])
    }

    @Test func unknownSizeRemainsInPackageSeriesWithoutInventingAUnitPrice() {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let wrongUnit = observation(100, unit: .item, product: product, store: store)
        let known = observation(300, day: 1, product: product, store: store)
        let unknown = observation(320, day: 2, unit: nil, quantity: nil, product: product, store: store)
        product.observations = [wrongUnit, known, unknown]
        #expect(PriceMath.series(for: product, store: store).map(\.id) == [known.id])
        #expect(PriceMath.series(for: product, store: store, includeUnknownSize: true).map(\.id) == [known.id, unknown.id])
        #expect(unknown.unitPrice == nil)
        #expect(unknown.headlineUnit == "AMD")
    }

    @Test func backdatedInsertionDoesNotReplaceTheLatestConditionalObservation() {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let latest = observation(280, day: 5, condition: .card, label: "Club", product: product, store: store)
        let backdated = observation(300, day: 1, product: product, store: store)
        product.observations = [latest, backdated]
        #expect(product.latestObservation?.id == latest.id)
        #expect(product.latestRegularObservation?.id == backdated.id)
    }
}
