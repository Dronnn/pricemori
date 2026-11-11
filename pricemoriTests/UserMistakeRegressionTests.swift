import Foundation
import SwiftData
import Testing
@testable import pricemori

@MainActor
struct UserMistakeRegressionTests {
    @Test(arguments: ["", "0", "-1", "abc", "1.2.3", "NaN", "∞", "1e999"])
    func invalidPriceCannotCreateOrDamageAnExistingRecord(_ input: String) {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let observation = PriceObservation(price: 300, currencyCode: "AMD", product: product, store: store)
        let otherProduct = Product(name: "Bread")
        var draft = ObservationDraft()
        draft.priceText = input
        #expect(draft.makeObservation(product: product, store: store) == nil)
        #expect(!draft.applyCorrection(to: observation, product: otherProduct))
        #expect(observation.price == 300)
        #expect(observation.product?.id == product.id)
    }

    @Test func wrongProductAndBranchCanBeCorrectedWithoutLosingIdentityOrUndoDestination() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let wrongProduct = Product(name: "Wrong product")
        let correctProduct = Product(name: "Correct product")
        let wrongStore = StoreLocation(name: "Shop", branch: "Wrong branch")
        let correctStore = StoreLocation(name: "Shop", branch: "Correct branch")
        for product in [wrongProduct, correctProduct] { context.insert(product) }
        for store in [wrongStore, correctStore] { context.insert(store) }
        let observation = PriceObservation(price: 111, currencyCode: "USD", product: wrongProduct, store: wrongStore)
        context.insert(observation)
        try context.save()
        let id = observation.id
        let createdAt = observation.createdAt
        var draft = ObservationDraft()
        draft.priceText = "444"
        draft.currencyCode = "AMD"
        draft.observedAt = Date(timeIntervalSince1970: 10_000)
        #expect(draft.applyCorrection(to: observation, product: correctProduct, store: correctStore))
        try context.save()
        #expect(observation.id == id && observation.createdAt == createdAt)
        #expect(wrongProduct.observations.isEmpty)
        #expect(correctProduct.observations.count == 1)
        #expect(wrongStore.observations.isEmpty)
        #expect(correctStore.observations.count == 1)
        #expect(ChartBasis.preferred(for: observation) == .package)
        #expect(PriceMath.series(for: correctProduct, store: correctStore, currency: "AMD", includeUnknownSize: true).count == 1)
        let snapshot = ObservationSnapshot(observation)
        context.delete(observation)
        try context.save()
        let restored = snapshot.makeObservation(product: wrongProduct, store: wrongStore)
        context.insert(restored)
        try context.save()
        #expect(restored.product?.id == correctProduct.id)
        #expect(restored.store?.id == correctStore.id)
        #expect(restored.id == id)
    }

    @Test func fixingUnknownSizeEnablesUnitChartAndRemovingSizeKeepsPackageHistory() {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let observation = PriceObservation(price: 300, currencyCode: "AMD", sizeKnown: false, product: product, store: store)
        product.observations = [observation]
        var draft = ObservationDraft()
        draft.priceText = "300"
        draft.sizeKnown = true
        draft.quantityText = "900"
        draft.unit = .gram
        #expect(draft.applyCorrection(to: observation))
        #expect(ChartBasis.preferred(for: observation) == .unit)
        #expect(PriceMath.series(for: product, store: store).count == 1)
        draft.sizeKnown = false
        draft.quantityText = ""
        #expect(draft.applyCorrection(to: observation))
        #expect(ChartBasis.preferred(for: observation) == .package)
        #expect(observation.unitPrice == nil)
        #expect(PriceMath.series(for: product, store: store, includeUnknownSize: true).count == 1)
    }

    @Test func archiveRestorePreservesPricesAndPermanentDeletionKeepsOtherProductsAndBranches() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let product = Product(name: "Rice")
        let other = Product(name: "Bread")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        context.insert(product)
        context.insert(other)
        context.insert(store)
        for value in [111, 222, 444] {
            context.insert(PriceObservation(price: Decimal(value), currencyCode: "AMD", sizeKnown: false, product: product, store: store))
        }
        context.insert(PriceObservation(price: 500, currencyCode: "AMD", sizeKnown: false, product: other, store: store))
        try context.save()
        product.isArchived = true
        product.archivedAt = .now
        try context.save()
        #expect(product.observations.count == 3)
        #expect(PriceMath.series(for: product, store: store, includeUnknownSize: true).count == 3)
        product.isArchived = false
        product.archivedAt = nil
        try context.save()
        #expect(product.observations.count == 3)
        context.delete(product)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PriceObservation>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<StoreLocation>()) == 1)
        #expect(other.observations.count == 1)
    }

    @Test func incompatibleEntriesRemainSavedWhileChartsKeepScopesSeparate() {
        let product = Product(name: "Rice")
        let firstStore = StoreLocation(name: "Shop", branch: "One")
        let otherStore = StoreLocation(name: "Shop", branch: "Two")
        let first = PriceObservation(price: 111, currencyCode: "AMD", sizeKnown: false, product: product, store: firstStore)
        let otherCurrency = PriceObservation(price: 1, currencyCode: "USD", sizeKnown: false, product: product, store: firstStore)
        let card = PriceObservation(price: 90, currencyCode: "AMD", sizeKnown: false, condition: .card, conditionLabel: "Club", product: product, store: firstStore)
        let otherBranch = PriceObservation(price: 100, currencyCode: "AMD", sizeKnown: false, product: product, store: otherStore)
        product.observations = [first, otherCurrency, card, otherBranch]
        let scoped = PriceMath.series(for: product, store: firstStore, currency: "AMD", reference: first, includeUnknownSize: true)
        #expect(scoped.map(\.id) == [first.id])
        #expect(product.sortedObservations.count == 4)
        #expect(ChartValues.percentChange(scoped, basis: .package) == nil)
        #expect(PriceMath.series(for: product, store: firstStore, condition: .card, currency: "AMD", reference: card, includeUnknownSize: true).count == 1)
    }
}
