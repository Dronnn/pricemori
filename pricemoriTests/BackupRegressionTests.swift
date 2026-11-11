import Foundation
import SwiftData
import Testing
@testable import pricemori

@MainActor
struct BackupRegressionTests {
    private func container() throws -> ModelContainer {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func fixture() -> BackupFile {
        let date = Date(timeIntervalSince1970: 1_760_000_000)
        let product = BackupProduct(id: UUID(), name: "Rice", brand: "Brand", variety: "Brown", isFavorite: true, isArchived: true, archivedAt: date, createdAt: date)
        let store = BackupStore(id: UUID(), name: "Shop", branch: "North", city: "Yerevan", note: "Entrance", isArchived: true, archivedAt: date, createdAt: date)
        let observation = BackupObservation(
            id: UUID(), productID: product.id, storeID: store.id, price: "900", currencyCode: "AMD",
            observedAt: date, createdAt: date.addingTimeInterval(-60), updatedAt: date.addingTimeInterval(60),
            packageQuantity: "0.9", packageUnit: MeasurementUnit.kilogram.rawValue,
            sizeKnown: true, isLoose: false, condition: ObservationCondition.multiBuy.rawValue,
            conditionLabel: "Weekend", conditionEndDate: date.addingTimeInterval(86_400),
            multiBuyMinimum: 3, source: ObservationSource.paid.rawValue, note: "Original note"
        )
        return BackupFile(format: BackupService.formatName, version: 1, exportedAt: date,
                          settings: BackupSettings(currencyCode: "USD", defaultSource: "paid", appLanguage: "de"),
                          products: [product], stores: [store], observations: [observation])
    }

    @Test func replacementOfPopulatedJournalPreservesEveryBackupField() throws {
        let container = try container()
        let context = container.mainContext
        let old = fixture()
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: old, context: context), choices: [:], context: context)
        let incoming = fixture()
        let suite = "BackupRegressionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("AMD", forKey: "currencyCode")
        defaults.set("en", forKey: AppLanguage.storageKey)

        _ = try BackupService.replace(with: incoming, context: context, defaults: defaults)
        let restored = try BackupService.makeBackup(context: context, defaults: defaults)
        #expect(restored.products == incoming.products)
        #expect(restored.stores == incoming.stores)
        #expect(restored.observations == incoming.observations)
        #expect(restored.settings == incoming.settings)
        #expect(!restored.observations.contains { $0.id == old.observations[0].id })
    }

    @Test func choosingBackupRestoresRelationshipsAndEveryObservationField() throws {
        let container = try container()
        let context = container.mainContext
        let original = fixture()
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: original, context: context), choices: [:], context: context)
        var incoming = fixture()
        incoming.observations[0].id = original.observations[0].id
        incoming.observations[0].price = "850"
        incoming.observations[0].createdAt = incoming.observations[0].createdAt.addingTimeInterval(-600)
        incoming.observations[0].source = "shelf"
        incoming.observations[0].isLoose = true
        incoming.observations[0].note = "Backup version"
        let plan = try BackupService.plan(backup: incoming, context: context)
        #expect(plan.conflicts.count == 1)

        _ = try BackupService.applyMerge(plan: plan, choices: [incoming.observations[0].id: .backup], context: context)
        let restored = try context.fetch(FetchDescriptor<PriceObservation>())
        #expect(restored.count == 1)
        let record = try #require(restored.first)
        #expect(try BackupObservation(record) == incoming.observations[0])
        #expect(record.product?.id == incoming.products[0].id)
        #expect(record.store?.id == incoming.stores[0].id)
    }

    @Test func malformedDefaultsAreRejectedBeforeChangingPopulatedJournal() throws {
        let container = try container()
        let context = container.mainContext
        let original = fixture()
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: original, context: context), choices: [:], context: context)
        let suite = "BackupRegressionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("AMD", forKey: "currencyCode")
        defaults.set("shelf", forKey: "defaultSource")
        defaults.set("en", forKey: AppLanguage.storageKey)
        let invalidSettings = [
            BackupSettings(currencyCode: "", defaultSource: "shelf"),
            BackupSettings(currencyCode: "ZZZ", defaultSource: "shelf"),
            BackupSettings(currencyCode: "AMD", defaultSource: "unknown"),
            BackupSettings(currencyCode: "AMD", defaultSource: "shelf", appLanguage: "unknown")
        ]
        for settings in invalidSettings {
            var invalid = fixture()
            invalid.settings = settings
            #expect(throws: BackupError.self) {
                try BackupService.replace(with: invalid, context: context, defaults: defaults)
            }
            let remaining = try BackupService.makeBackup(context: context, defaults: defaults)
            #expect(remaining.observations == original.observations)
            #expect(remaining.products == original.products)
            #expect(remaining.stores == original.stores)
            #expect(remaining.settings == BackupSettings(currencyCode: "AMD", defaultSource: "shelf", appLanguage: "en"))
        }
    }

    @Test func legacyBackupWithoutLanguagePreservesCurrentLanguage() throws {
        var old = fixture()
        old.settings.appLanguage = nil
        let encoded = try BackupService.encode(old)
        let decoded = try BackupService.decode(encoded)
        #expect(decoded.settings.appLanguage == nil)
        let container = try container()
        let suite = "BackupRegressionTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("ru", forKey: AppLanguage.storageKey)

        _ = try BackupService.replace(with: decoded, context: container.mainContext, defaults: defaults)
        #expect(defaults.string(forKey: AppLanguage.storageKey) == "ru")
    }

    @Test func cardOfferIsIdenticalAfterFileRoundTrip() throws {
        let container = try container()
        let context = container.mainContext
        var source = fixture()
        source.observations[0].condition = "card"
        source.observations[0].multiBuyMinimum = 1
        source.observations[0].conditionEndDate = Date(timeIntervalSince1970: 1_760_000_000.375)
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: source, context: context), choices: [:], context: context)
        let decoded = try BackupService.decode(BackupService.encode(BackupService.makeBackup(context: context)))
        let plan = try BackupService.plan(backup: decoded, context: context)
        #expect(plan.identical == 1)
        #expect(plan.conflicts.isEmpty)
    }

    @Test func csvRetainsUnknownSizeAndOfferBasis() throws {
        let container = try container()
        let context = container.mainContext
        var source = fixture()
        source.observations[0].sizeKnown = false
        source.observations[0].packageQuantity = nil
        source.observations[0].packageUnit = nil
        source.observations[0].isLoose = true
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: source, context: context), choices: [:], context: context)
        let csv = try CSVExport.makeData(context: context)
        let rows = String(decoding: csv.data, as: UTF8.self).components(separatedBy: "\r\n")
        let fields = Dictionary(uniqueKeysWithValues: zip(rows[0].components(separatedBy: ","), rows[1].components(separatedBy: ",")))
        #expect(csv.rows == 1)
        #expect(fields["size_known"] == "false")
        #expect(fields["is_loose"] == "true")
        #expect(fields["multi_buy_minimum"] == "3")
        #expect(fields["condition_end_date"] == ISO8601DateFormatter().string(from: try #require(source.observations[0].conditionEndDate)))
        #expect(fields["price_basis"] == "total_for_minimum_packages")
        #expect(fields["package_quantity"] == "")
        #expect(fields["unit_price"] == "")
    }

    @Test func mergePreservesLocalProductAndBranchMetadata() throws {
        let container = try container()
        let context = container.mainContext
        let original = fixture()
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: original, context: context), choices: [:], context: context)
        var incoming = original
        incoming.products[0].name = "Different product label"
        incoming.stores[0].branch = "Different branch label"
        incoming.observations[0].id = UUID()
        _ = try BackupService.applyMerge(plan: BackupService.plan(backup: incoming, context: context), choices: [:], context: context)
        let merged = try BackupService.makeBackup(context: context)
        #expect(merged.products == original.products)
        #expect(merged.stores == original.stores)
        #expect(merged.observations.count == 2)
    }

    @Test func invalidAmountSuffixAndSchemaVersionAreRejected() throws {
        var source = fixture()
        source.observations[0].price = "900oops"
        #expect(throws: BackupError.self) { try BackupService.validate(source) }
        source = fixture()
        source.version = 0
        #expect(throws: BackupError.self) { try BackupService.validate(source) }
    }
}
