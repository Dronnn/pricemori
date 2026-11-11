import Foundation
import SwiftData

enum SampleData {
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-seed-sample") else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Product>())) ?? 0
        guard count == 0 else { return }
        seed(context: context)
        #endif
    }

    @MainActor
    static func seed(context: ModelContext, reference: Date = .now) {
        let calendar = Calendar.current
        let now = reference
        func day(_ offset: Int, hour: Int = 12, minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        func today(_ hour: Int, _ minute: Int = 0) -> Date {
            let latest = min(day(0, hour: 9, minute: 35), now.addingTimeInterval(-1800))
            return latest.addingTimeInterval(Double(hour * 60 + minute - (9 * 60 + 35)) * 60)
        }

        let sas = StoreLocation(name: "SAS", branch: "Komitas 12", city: "Yerevan", note: "Near home")
        let norZovq = StoreLocation(name: "Nor Zovq", branch: "Abovyan", city: "Yerevan")
        let carrefour = StoreLocation(name: "Carrefour", branch: "Mall", city: "Yerevan")
        let archivedStore = StoreLocation(
            name: "City Market",
            branch: "Old branch",
            city: "Yerevan",
            isArchived: true,
            archivedAt: day(-10)
        )

        let buckwheat = Product(name: "Buckwheat", brand: "Brand X", variety: "Whole grain", isFavorite: true)
        let bread = Product(name: "Bread", brand: "Wholemeal")
        let detergent = Product(name: "Detergent", brand: "Brand Y")
        let archivedProduct = Product(
            name: "Oat milk",
            brand: "Brand Q",
            isArchived: true,
            archivedAt: day(-14)
        )

        let observations: [PriceObservation] = [
            PriceObservation(
                price: 260,
                currencyCode: "AMD",
                observedAt: day(-56, hour: 10, minute: 5),
                packageQuantity: 1,
                packageUnit: .kilogram,
                source: .shelf,
                note: "First recorded price",
                product: buckwheat,
                store: sas
            ),
            PriceObservation(
                price: 300,
                currencyCode: "AMD",
                observedAt: day(-28, hour: 11, minute: 20),
                packageQuantity: 1,
                packageUnit: .kilogram,
                source: .paid,
                product: buckwheat,
                store: sas
            ),
            PriceObservation(
                price: 320,
                currencyCode: "AMD",
                observedAt: today(9, 35),
                packageQuantity: 1,
                packageUnit: .kilogram,
                source: .shelf,
                product: buckwheat,
                store: sas
            ),
            PriceObservation(
                price: 280,
                currencyCode: "AMD",
                observedAt: today(9, 10),
                packageQuantity: 1,
                packageUnit: .kilogram,
                condition: .card,
                conditionLabel: "SAS Club card required",
                source: .shelf,
                product: buckwheat,
                store: sas
            ),
            PriceObservation(
                price: 900,
                currencyCode: "AMD",
                observedAt: today(8, 50),
                packageQuantity: 1,
                packageUnit: .kilogram,
                condition: .multiBuy,
                multiBuyMinimum: 3,
                source: .shelf,
                product: buckwheat,
                store: sas
            ),
            PriceObservation(
                price: 280,
                currencyCode: "AMD",
                observedAt: day(-30, hour: 16, minute: 0),
                packageQuantity: 1,
                packageUnit: .kilogram,
                source: .shelf,
                product: buckwheat,
                store: carrefour
            ),
            PriceObservation(
                price: 250,
                currencyCode: "AMD",
                observedAt: day(-40, hour: 12, minute: 0),
                packageQuantity: nil,
                packageUnit: nil,
                sizeKnown: false,
                source: .shelf,
                product: buckwheat,
                store: carrefour
            ),
            PriceObservation(
                price: Decimal(string: "0.75")!,
                currencyCode: "USD",
                observedAt: day(-35, hour: 12, minute: 0),
                packageQuantity: 1,
                packageUnit: .kilogram,
                source: .shelf,
                product: buckwheat,
                store: carrefour
            ),
            PriceObservation(
                price: 100,
                currencyCode: "AMD",
                observedAt: day(-45, hour: 12, minute: 0),
                packageQuantity: 1,
                packageUnit: .item,
                source: .shelf,
                product: buckwheat,
                store: carrefour
            ),
            PriceObservation(
                price: 300,
                currencyCode: "AMD",
                observedAt: day(-1, hour: 17, minute: 10),
                packageQuantity: 900,
                packageUnit: .gram,
                source: .shelf,
                product: buckwheat,
                store: norZovq
            ),
            PriceObservation(
                price: 500,
                currencyCode: "AMD",
                observedAt: day(-28, hour: 9, minute: 40),
                packageQuantity: 1,
                packageUnit: .loaf,
                source: .shelf,
                product: bread,
                store: sas
            ),
            PriceObservation(
                price: 450,
                currencyCode: "AMD",
                observedAt: day(-3, hour: 9, minute: 30),
                packageQuantity: 1,
                packageUnit: .loaf,
                source: .paid,
                product: bread,
                store: sas
            ),
            PriceObservation(
                price: 450,
                currencyCode: "AMD",
                observedAt: day(-1, hour: 18, minute: 0),
                packageQuantity: 1,
                packageUnit: .loaf,
                source: .shelf,
                product: bread,
                store: norZovq
            ),
            PriceObservation(
                price: 1900,
                currencyCode: "AMD",
                observedAt: day(-30, hour: 16, minute: 30),
                packageQuantity: Decimal(string: "1.5"),
                packageUnit: .liter,
                source: .shelf,
                product: detergent,
                store: carrefour
            ),
            PriceObservation(
                price: 400,
                currencyCode: "AMD",
                observedAt: day(-60, hour: 11, minute: 0),
                packageQuantity: 1,
                packageUnit: .liter,
                source: .shelf,
                product: archivedProduct,
                store: archivedStore
            )
        ]

        for store in [sas, norZovq, carrefour, archivedStore] { context.insert(store) }
        for product in [buckwheat, bread, detergent, archivedProduct] { context.insert(product) }
        for observation in observations { context.insert(observation) }
        try? context.save()
    }

    @MainActor
    static func clear(context: ModelContext) {
        if let observations = try? context.fetch(FetchDescriptor<PriceObservation>()) {
            for observation in observations { context.delete(observation) }
        }
        if let products = try? context.fetch(FetchDescriptor<Product>()) {
            for product in products { context.delete(product) }
        }
        if let stores = try? context.fetch(FetchDescriptor<StoreLocation>()) {
            for store in stores { context.delete(store) }
        }
        try? context.save()
    }
}
