import Foundation
import SwiftData
import Testing
@testable import pricemori

@MainActor
@Suite(.serialized)
struct PricemoriTests {
    init() {
        UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
    }

    private func date(_ day: Int) -> Date {
        Date(timeIntervalSince1970: 1_760_000_000).addingTimeInterval(Double(day) * 86_400)
    }

    private func observation(
        price: Decimal,
        quantity: Decimal? = 1,
        unit: MeasurementUnit? = .kilogram,
        sizeKnown: Bool = true,
        condition: ObservationCondition = .regular,
        conditionLabel: String = "",
        multiBuyMinimum: Int = 1,
        currency: String = "AMD",
        store: StoreLocation,
        date: Date
    ) -> PriceObservation {
        PriceObservation(
            price: price,
            currencyCode: currency,
            observedAt: date,
            packageQuantity: quantity,
            packageUnit: unit,
            sizeKnown: sizeKnown,
            condition: condition,
            conditionLabel: conditionLabel,
            multiBuyMinimum: multiBuyMinimum,
            store: store
        )
    }

    @Test func percentageChange() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(price: 300, store: store, date: date(0))
        let current = observation(price: 320, store: store, date: date(28))

        let change = PriceMath.change(current: current, previous: previous)
        #expect(change != nil)
        #expect(change?.amount == 20)
        #expect(abs(NSDecimalNumber(decimal: change?.percent ?? 0).doubleValue - 6.6666) < 0.001)
        #expect(change.map { Format.percent($0.percent) } == "+6.7%")
    }

    @Test func unitPriceNormalizesPackageSize() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let small = observation(
            price: 300,
            quantity: 900,
            unit: .gram,
            store: store,
            date: date(0)
        )
        #expect(abs(NSDecimalNumber(decimal: small.unitPrice ?? 0).doubleValue - 333.3333) < 0.001)
        #expect(Format.number(small.unitPrice ?? 0, maxFraction: 2) == "333.33")
    }

    @Test func shrinkingPackageRaisesUnitPrice() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(price: 300, quantity: 1, unit: .kilogram, store: store, date: date(0))
        let current = observation(price: 300, quantity: 900, unit: .gram, store: store, date: date(28))

        let change = PriceMath.change(current: current, previous: previous)
        #expect(change != nil)
        #expect(abs(NSDecimalNumber(decimal: change?.amount ?? 0).doubleValue - 33.3333) < 0.001)
        #expect(abs(NSDecimalNumber(decimal: change?.percent ?? 0).doubleValue - 11.1111) < 0.001)
    }

    @Test func differentStoresDoNotCreateTemporalChange() {
        let sas = StoreLocation(name: "SAS", branch: "Komitas 12")
        let carrefour = StoreLocation(name: "Carrefour", branch: "Mall")
        let previous = observation(price: 280, store: carrefour, date: date(0))
        let current = observation(price: 320, store: sas, date: date(28))

        #expect(PriceMath.change(for: current, among: [previous, current]) == nil)
    }

    @Test func differentCurrenciesAreNotCompared() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(price: 300, currency: "AMD", store: store, date: date(0))
        let current = observation(price: 1, currency: "USD", store: store, date: date(28))

        #expect(PriceMath.change(for: current, among: [previous, current]) == nil)
        #expect(current.unitPrice != nil)
    }

    @Test func unknownPackageSizeHasNoUnitPriceOrTrend() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(price: 300, store: store, date: date(0))
        let current = observation(
            price: 300,
            quantity: nil,
            unit: nil,
            sizeKnown: false,
            store: store,
            date: date(28)
        )

        #expect(current.unitPrice == nil)
        #expect(PriceMath.change(for: current, among: [previous, current]) == nil)
    }

    @Test func incompatibleDimensionsAreNotCompared() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(price: 300, quantity: 1, unit: .kilogram, store: store, date: date(0))
        let current = observation(price: 100, quantity: 1, unit: .item, store: store, date: date(28))

        #expect(PriceMath.change(for: current, among: [previous, current]) == nil)
    }

    @Test func conditionsStaySeparate() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let regular = observation(price: 300, store: store, date: date(0))
        let card = observation(
            price: 280,
            condition: .card,
            conditionLabel: "SAS Club card required",
            store: store,
            date: date(28)
        )

        #expect(PriceMath.change(for: card, among: [regular, card]) == nil)
    }

    @Test func cardOffersWithDifferentLabelsAreNotCompared() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let first = observation(price: 280, condition: .card, conditionLabel: "SAS Club", store: store, date: date(0))
        let second = observation(price: 270, condition: .card, conditionLabel: "Other card", store: store, date: date(28))

        #expect(PriceMath.change(for: second, among: [first, second]) == nil)
    }

    @Test func previousComparableUsesObservationDates() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let first = observation(price: 260, store: store, date: date(0))
        let previous = observation(price: 300, store: store, date: date(28))
        let backdated = observation(price: 250, store: store, date: date(10))
        let current = observation(price: 320, store: store, date: date(56))

        let previousComparable = PriceMath.previousComparable(for: current, among: [first, previous, backdated, current])
        #expect(previousComparable?.price == 300)
        #expect(PriceMath.latestObservation(for: Product(name: "Test"), condition: .regular) == nil)
    }

    @Test func nineHundredGramsVersusOneKilogram() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(price: 300, quantity: 900, unit: .gram, store: store, date: date(0))
        let current = observation(price: 320, quantity: 1, unit: .kilogram, store: store, date: date(28))

        let change = PriceMath.change(current: current, previous: previous)
        #expect(change != nil)
        #expect(abs(NSDecimalNumber(decimal: previous.unitPrice ?? 0).doubleValue - 333.3333) < 0.001)
        #expect(current.unitPrice == 320)
        #expect(abs(NSDecimalNumber(decimal: change?.amount ?? 0).doubleValue + 13.3333) < 0.001)
        #expect(abs(NSDecimalNumber(decimal: change?.percent ?? 0).doubleValue + 4.0) < 0.001)
    }

    @Test func allLanguageBundlesResolve() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppLanguage.storageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }

        let expectations: [String: String] = [
            "de": "Abbrechen",
            "fr": "Annuler",
            "es": "Cancelar",
            "pt-BR": "Cancelar",
            "pl": "Anuluj",
            "ru": "Отмена",
            "uk": "Скасувати",
            "hy": "Չեղարկել",
            "ja": "キャンセル",
            "ko": "취소",
            "zh-Hans": "取消",
            "vi": "Hủy",
            "it": "Annulla",
            "nl": "Annuleer",
            "tr": "İptal",
            "id": "Batal"
        ]

        for (code, expected) in expectations {
            defaults.set(code, forKey: AppLanguage.storageKey)
            #expect(L10n.string("Cancel") == expected, "Language \(code)")
        }

        defaults.set("en", forKey: AppLanguage.storageKey)
        #expect(L10n.string("Cancel") == "Cancel")
    }

    @Test func localizedStringsLoadFromBundles() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppLanguage.storageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }

        defaults.set(AppLanguage.german.rawValue, forKey: AppLanguage.storageKey)
        #expect(L10n.string("Journal") == "Tagebuch")
        #expect(L10n.string("Settings") == "Einstellungen")

        defaults.set(AppLanguage.russian.rawValue, forKey: AppLanguage.storageKey)
        #expect(L10n.string("Journal") == "Журнал")

        defaults.set(AppLanguage.armenian.rawValue, forKey: AppLanguage.storageKey)
        #expect(L10n.string("Journal") == "Օրագիր")
    }

    @Test func staleAgeIsReported() {
        let now = date(30)
        #expect(Format.relativeAge(date(0), relativeTo: now) == "30 days ago")
        #expect(Format.relativeAge(date(29), relativeTo: now) == "Yesterday")
        #expect(Format.relativeAge(now, relativeTo: now) == "Today")
    }

    @Test func multiBuyComparisonUsesPerPackagePrice() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let previous = observation(
            price: 900,
            quantity: 1,
            unit: .kilogram,
            condition: .multiBuy,
            multiBuyMinimum: 3,
            store: store,
            date: date(0)
        )
        let current = observation(
            price: 960,
            quantity: 1,
            unit: .kilogram,
            condition: .multiBuy,
            multiBuyMinimum: 3,
            store: store,
            date: date(28)
        )

        let change = PriceMath.change(current: current, previous: previous)
        #expect(change?.amount == 20)
        #expect(abs(NSDecimalNumber(decimal: change?.percent ?? 0).doubleValue - 6.6666) < 0.001)
        #expect(Format.percent(change?.percent ?? 0) == "+6.7%")
    }

    @Test func multiBuyUsesPerPackagePrice() {
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let multi = observation(
            price: 900,
            quantity: 1,
            unit: .kilogram,
            condition: .multiBuy,
            multiBuyMinimum: 3,
            store: store,
            date: date(0)
        )

        #expect(multi.effectivePackagePrice == 300)
        #expect(multi.unitPrice == 300)
    }

    @Test func currencyRoundingUsesMinorUnits() {
        #expect(Format.roundedForCurrency(Decimal(string: "300.6")!, currency: "AMD") == 301)
        #expect(Format.roundedForCurrency(Decimal(string: "300.6")!, currency: "USD") == Decimal(string: "300.6")!)
    }

    @Test func backupRoundTripAndMergePlan() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let product = Product(name: "Buckwheat", brand: "Brand X")
        let store = StoreLocation(name: "SAS", branch: "Komitas 12", city: "Yerevan")
        let observation = PriceObservation(
            price: 320,
            currencyCode: "AMD",
            observedAt: date(0),
            packageQuantity: 1,
            packageUnit: .kilogram,
            product: product,
            store: store
        )
        context.insert(product)
        context.insert(store)
        context.insert(observation)
        try context.save()

        let backup = try BackupService.makeBackup(context: context)
        let data = try BackupService.encode(backup)
        let decoded = try BackupService.decode(data)
        #expect(decoded.products.count == 1)
        #expect(decoded.stores.count == 1)
        #expect(decoded.observations.count == 1)

        let plan = try BackupService.plan(backup: decoded, context: context)
        #expect(plan.newObservations == 0)
        #expect(plan.identical == 1)
        #expect(plan.conflicts.isEmpty)

        var changed = decoded
        changed.observations[0].price = "999"
        let conflictPlan = try BackupService.plan(backup: changed, context: context)
        #expect(conflictPlan.conflicts.count == 1)

        _ = try BackupService.applyMerge(plan: conflictPlan, choices: [observation.id: .backup], context: context)
        #expect(observation.price == 999)
    }

    @Test func mergeIntoEmptyJournalInsertsProductsStoresAndObservations() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let sourceContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let source = sourceContainer.mainContext

        let product = Product(name: "Rice", brand: "Brand R")
        let store = StoreLocation(name: "Nor Zovq", branch: "Abovyan", city: "Yerevan")
        source.insert(product)
        source.insert(store)
        source.insert(PriceObservation(
            price: 500,
            currencyCode: "AMD",
            observedAt: date(0),
            packageQuantity: 1,
            packageUnit: .kilogram,
            product: product,
            store: store
        ))
        try source.save()
        let backup = try BackupService.makeBackup(context: source)

        let targetContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let target = targetContainer.mainContext
        let plan = try BackupService.plan(backup: backup, context: target)
        #expect(plan.newProducts == 1)
        #expect(plan.newStores == 1)
        #expect(plan.newObservations == 1)
        #expect(plan.conflicts.isEmpty)

        let result = try BackupService.applyMerge(plan: plan, choices: [:], context: target)
        #expect(result.addedObservations == 1)
        #expect(try target.fetchCount(FetchDescriptor<Product>()) == 1)
        #expect(try target.fetchCount(FetchDescriptor<StoreLocation>()) == 1)
        #expect(try target.fetchCount(FetchDescriptor<PriceObservation>()) == 1)
        let imported = try target.fetch(FetchDescriptor<PriceObservation>()).first
        #expect(imported?.product?.name == "Rice")
        #expect(imported?.store?.displayName == "Nor Zovq · Abovyan")
    }

    @Test func replacementRestoresBackup() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let product = Product(name: "Buckwheat", brand: "Brand X")
        let store = StoreLocation(name: "SAS", branch: "Komitas 12")
        let observation = PriceObservation(
            price: 320,
            currencyCode: "AMD",
            observedAt: date(0),
            packageQuantity: 1,
            packageUnit: .kilogram,
            product: product,
            store: store
        )
        context.insert(product)
        context.insert(store)
        context.insert(observation)
        try context.save()

        let backup = try BackupService.makeBackup(context: context)
        SampleData.clear(context: context)
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 0)

        let result = try BackupService.replace(with: backup, context: context)
        #expect(result.isReplacement)
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<StoreLocation>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PriceObservation>()) == 1)
        let restored = try context.fetch(FetchDescriptor<PriceObservation>()).first
        #expect(restored?.price == 320)
        #expect(restored?.product?.name == "Buckwheat")
    }

    @Test func invalidBackupReferenceIsRejected() throws {
        var backup = BackupFile(
            format: BackupService.formatName,
            version: 1,
            exportedAt: .now,
            settings: BackupSettings(currencyCode: "AMD", defaultSource: "shelf"),
            products: [],
            stores: [],
            observations: []
        )
        backup.observations = [
            BackupObservation(
                id: UUID(),
                productID: UUID(),
                storeID: UUID(),
                price: "300",
                currencyCode: "AMD",
                observedAt: .now,
                createdAt: .now,
                updatedAt: .now,
                packageQuantity: "1",
                packageUnit: "kilogram",
                sizeKnown: true,
                isLoose: false,
                condition: "regular",
                conditionLabel: "",
                conditionEndDate: nil,
                multiBuyMinimum: 1,
                source: "shelf",
                note: ""
            )
        ]
        #expect(throws: BackupError.self) {
            try BackupService.validate(backup)
        }
    }

    @Test func newerBackupVersionIsRejected() throws {
        let backup = BackupFile(
            format: BackupService.formatName,
            version: 99,
            exportedAt: .now,
            settings: BackupSettings(currencyCode: "AMD", defaultSource: "shelf"),
            products: [],
            stores: [],
            observations: []
        )
        #expect(throws: BackupError.self) {
            try BackupService.validate(backup)
        }
    }

    @Test func csvExportContainsHeaderAndRows() throws {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let product = Product(name: "Bread", brand: "Wholemeal")
        let store = StoreLocation(name: "Nor Zovq", branch: "Abovyan", city: "Yerevan")
        let observation = PriceObservation(
            price: 450,
            currencyCode: "AMD",
            observedAt: date(0),
            packageQuantity: 1,
            packageUnit: .item,
            source: .paid,
            product: product,
            store: store
        )
        context.insert(product)
        context.insert(store)
        context.insert(observation)
        try context.save()

        let csv = try CSVExport.makeData(context: context)
        let text = String(decoding: csv.data, as: UTF8.self)
        #expect(csv.rows == 1)
        #expect(text.contains("product,brand,variety"))
        #expect(text.contains("Bread,Wholemeal"))
    }
}
