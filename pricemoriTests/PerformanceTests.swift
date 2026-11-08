import Foundation
import SwiftData
import Testing
@testable import pricemori

@MainActor
struct PerformanceTests {
    @Test func thousandProductJournalComputationStaysBounded() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        context.insert(store)

        let now = Date.now
        for index in 0..<1000 {
            let product = Product(name: "Product \(index)", brand: "Brand \(index % 7)")
            context.insert(product)
            for observationIndex in 0..<5 {
                let date = Calendar.current.date(byAdding: .day, value: -90 + observationIndex * 10, to: now) ?? now
                context.insert(PriceObservation(
                    price: Decimal(300 + index % 100 + observationIndex * 5),
                    currencyCode: "AMD",
                    observedAt: date,
                    packageQuantity: 1,
                    packageUnit: .kilogram,
                    product: product,
                    store: store
                ))
            }
        }
        try context.save()

        let products = try context.fetch(FetchDescriptor<Product>())

        let start = Date()
        let entries = products.map { ($0, $0.latestRegularObservation) }
            .sorted { lhs, rhs in
                let left = lhs.1?.observedAt ?? lhs.0.createdAt
                let right = rhs.1?.observedAt ?? rhs.0.createdAt
                return left > right
            }
        let journalDuration = Date().timeIntervalSince(start)

        let changeStart = Date()
        let rows = PriceMath.periodChanges(
            products: products,
            store: store,
            from: Calendar.current.date(byAdding: .day, value: -100, to: now) ?? now,
            to: now,
            currency: "AMD"
        )
        let periodDuration = Date().timeIntervalSince(changeStart)

        #expect(entries.count == 1000)
        #expect(entries.allSatisfy { $0.1 != nil })
        #expect(rows.count == 1000)
        #expect(journalDuration < 2.0, "Journal rows took \(journalDuration)s")
        #expect(periodDuration < 3.0, "Period changes took \(periodDuration)s")
    }
}
