import Foundation
import Testing
import SwiftData
@testable import pricemori

@MainActor
struct ChartRegressionTests {
    @Test func unknownSizePricesRemainACompletePackageHistory() {
        let product = Product(name: "Package only")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let prices: [Decimal] = [111, 222, 33, 444]
        let records = prices.enumerated().map { offset, price in
            PriceObservation(price: price, currencyCode: "AMD", observedAt: Date(timeIntervalSince1970: Double(offset + 1)),
                             sizeKnown: false, product: product, store: store)
        }
        product.observations = records
        #expect(ChartBasis.preferred(for: product.latestObservation) == .package)
        #expect(PriceMath.series(for: product, store: store).isEmpty)
        let packageHistory = PriceMath.series(for: product, store: store, reference: records.last, includeUnknownSize: true)
        #expect(packageHistory.map(\.price) == prices)
        #expect(ChartValues.range(packageHistory, basis: .package) == 33...444)
        #expect(ChartValues.recordedRange(packageHistory, basis: .package)?.minimum.price == 33)
        #expect(ChartValues.recordedRange(packageHistory, basis: .package)?.maximum.price == 444)
        #expect(ChartValues.percentChange(packageHistory, basis: .package) == 300)
        #expect(ChartValues.percentChange(packageHistory, basis: .unit) == nil)
    }

    @Test func sampleChronologyIsStableAtEveryTimeOfDay() throws {
        for hour in [0, 8, 12, 23] {
            let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
            let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: hour, minute: 5))!
            SampleData.seed(context: container.mainContext, reference: date)
            let product = try #require(container.mainContext.fetch(FetchDescriptor<Product>()).first { $0.name == "Buckwheat" })
            #expect(product.latestObservation?.condition == .regular)
            #expect(product.latestObservation?.price == 320)
            #expect(product.observations.allSatisfy { $0.observedAt <= date })
        }
    }

    @Test func packageAndUnitChangesUseDifferentValues() {
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let first = PriceObservation(price: 300, currencyCode: "AMD", observedAt: Date(timeIntervalSince1970: 100), packageQuantity: 1, packageUnit: .kilogram, store: store)
        let last = PriceObservation(price: 300, currencyCode: "AMD", observedAt: Date(timeIntervalSince1970: 200), packageQuantity: 900, packageUnit: .gram, store: store)
        #expect(ChartValues.percentChange([first, last], basis: .package) == 0)
        #expect(abs(NSDecimalNumber(decimal: ChartValues.percentChange([first, last], basis: .unit) ?? 0).doubleValue - 11.1111) < 0.001)
        #expect(ChartValues.range([first, last], basis: .package) == 300...300)
        #expect(ChartValues.packageSizeChange([first, last])?.1.id == last.id)
    }

    @Test func equalSizesInDifferentUnitsAreNotShrinkage() {
        let first = PriceObservation(price: 300, currencyCode: "AMD", observedAt: Date(timeIntervalSince1970: 100), packageQuantity: 1, packageUnit: .kilogram)
        let last = PriceObservation(price: 350, currencyCode: "AMD", observedAt: Date(timeIntervalSince1970: 200), packageQuantity: 1000, packageUnit: .gram)
        #expect(ChartValues.packageSizeChange([first, last]) == nil)
    }

    @Test func dollarAndIntradayChartsKeepTheirUsefulScale() {
        let ticks = ChartValues.axisTicks([1, 1.2])
        #expect((ticks.last ?? 100) - (ticks.first ?? 0) < 1)
        #expect(ChartValues.axisFractionDigits(ticks) > 0)
        let first = Date(timeIntervalSince1970: 1000)
        let last = first.addingTimeInterval(3600)
        let domain = ChartValues.dateDomain([first, last])
        #expect(domain.contains(first) && domain.contains(last))
        #expect(domain.upperBound.timeIntervalSince(domain.lowerBound) < 7200)
    }

    @Test func nearbyIntradayTicksHaveDistinctTimeLabels() {
        let first = Date(timeIntervalSince1970: 1000)
        let second = first.addingTimeInterval(10)
        let domain = ChartValues.dateDomain([first, second])
        #expect(ChartValues.dateLabel(first, in: domain) != ChartValues.dateLabel(second, in: domain))
    }

    @Test func latestPriceIsPositionedInsideItsRange() {
        #expect(ChartValues.rangePosition(minimum: 300, maximum: 500, value: 350) == 0.25)
        #expect(ChartValues.rangePosition(minimum: 300, maximum: 300, value: 300) == 0.5)
    }

    @Test func undoSnapshotPreservesRecordIdentity() {
        let product = Product(name: "Rice")
        let store = StoreLocation(name: "Shop", branch: "Centre")
        let original = PriceObservation(price: 300, currencyCode: "AMD", product: product, store: store)
        let restored = ObservationSnapshot(original).makeObservation(product: product, store: store)
        #expect(restored.id == original.id)
        #expect(restored.updatedAt == original.updatedAt)
        #expect(restored.observedAt == original.observedAt)
    }
}
