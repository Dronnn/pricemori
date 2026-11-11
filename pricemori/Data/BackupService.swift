import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupSettings: Codable, Equatable {
    var currencyCode: String
    var defaultSource: String
    // Optional so version 1 backups created before language preferences still restore.
    var appLanguage: String? = nil
}

struct BackupProduct: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var brand: String
    var variety: String
    var isFavorite: Bool
    var isArchived: Bool
    var archivedAt: Date?
    var createdAt: Date

    init(_ product: Product) {
        id = product.id
        name = product.name
        brand = product.brand
        variety = product.variety
        isFavorite = product.isFavorite
        isArchived = product.isArchived
        archivedAt = product.archivedAt
        createdAt = product.createdAt
    }

    init(id: UUID, name: String, brand: String, variety: String, isFavorite: Bool, isArchived: Bool, archivedAt: Date?, createdAt: Date) {
        self.id = id
        self.name = name
        self.brand = brand
        self.variety = variety
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }
}

struct BackupStore: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var branch: String
    var city: String
    var note: String
    var isArchived: Bool
    var archivedAt: Date?
    var createdAt: Date

    init(_ store: StoreLocation) {
        id = store.id
        name = store.name
        branch = store.branch
        city = store.city
        note = store.note
        isArchived = store.isArchived
        archivedAt = store.archivedAt
        createdAt = store.createdAt
    }

    init(id: UUID, name: String, branch: String, city: String, note: String, isArchived: Bool, archivedAt: Date?, createdAt: Date) {
        self.id = id
        self.name = name
        self.branch = branch
        self.city = city
        self.note = note
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }
}

struct BackupObservation: Codable, Equatable, Identifiable {
    var id: UUID
    var productID: UUID
    var storeID: UUID
    var price: String
    var currencyCode: String
    var observedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var packageQuantity: String?
    var packageUnit: String?
    var sizeKnown: Bool
    var isLoose: Bool
    var condition: String
    var conditionLabel: String
    var conditionEndDate: Date?
    var multiBuyMinimum: Int
    var source: String
    var note: String

    init(_ observation: PriceObservation) throws {
        guard let product = observation.product, let store = observation.store else {
            throw BackupError(message: "An observation is missing its product or store.")
        }
        id = observation.id
        productID = product.id
        storeID = store.id
        price = NSDecimalNumber(decimal: observation.price).stringValue
        currencyCode = observation.currencyCode
        observedAt = Self.seconds(observation.observedAt)
        createdAt = Self.seconds(observation.createdAt)
        updatedAt = Self.seconds(observation.updatedAt)
        packageQuantity = observation.packageQuantity.map { NSDecimalNumber(decimal: $0).stringValue }
        packageUnit = observation.packageUnit?.rawValue
        sizeKnown = observation.sizeKnown
        isLoose = observation.isLoose
        condition = observation.condition.rawValue
        conditionLabel = observation.conditionLabel
        conditionEndDate = observation.conditionEndDate.map(Self.seconds)
        multiBuyMinimum = observation.multiBuyMinimum
        source = observation.source.rawValue
        note = observation.note
    }

    init(
        id: UUID,
        productID: UUID,
        storeID: UUID,
        price: String,
        currencyCode: String,
        observedAt: Date,
        createdAt: Date,
        updatedAt: Date,
        packageQuantity: String?,
        packageUnit: String?,
        sizeKnown: Bool,
        isLoose: Bool,
        condition: String,
        conditionLabel: String,
        conditionEndDate: Date?,
        multiBuyMinimum: Int,
        source: String,
        note: String
    ) {
        self.id = id
        self.productID = productID
        self.storeID = storeID
        self.price = price
        self.currencyCode = currencyCode
        self.observedAt = observedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.packageQuantity = packageQuantity
        self.packageUnit = packageUnit
        self.sizeKnown = sizeKnown
        self.isLoose = isLoose
        self.condition = condition
        self.conditionLabel = conditionLabel
        self.conditionEndDate = conditionEndDate
        self.multiBuyMinimum = multiBuyMinimum
        self.source = source
        self.note = note
    }

    private nonisolated static func seconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }

    var decimalPrice: Decimal? { Self.decimal(price) }
    var decimalQuantity: Decimal? {
        packageQuantity.flatMap(Self.decimal)
    }

    private nonisolated static func decimal(_ value: String) -> Decimal? {
        guard value.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct BackupFile: Codable, Equatable {
    var format: String
    var version: Int
    var exportedAt: Date
    var settings: BackupSettings
    var products: [BackupProduct]
    var stores: [BackupStore]
    var observations: [BackupObservation]
}

struct BackupError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ImportConflict: Identifiable {
    let id: UUID
    let productName: String
    let storeName: String
    let observedAt: Date
    let current: BackupObservation
    let backup: BackupObservation
}

struct MergePlan {
    let backup: BackupFile
    let newProducts: Int
    let newStores: Int
    let newObservations: Int
    let identical: Int
    let conflicts: [ImportConflict]
    let productsAfter: Int
    let storesAfter: Int
    let observationsAfter: Int

    var totalObservations: Int { backup.observations.count }
}

enum ConflictChoice: Equatable {
    case current
    case backup
}

struct ImportResult {
    let title: String
    let summary: String
    let addedObservations: Int
    let skippedObservations: Int
    let keptCurrent: Int
    let products: Int
    let stores: Int
    let observations: Int
    let isReplacement: Bool
}

enum BackupService {
    static let currentVersion = 1
    static let formatName = "pricemori.backup"

    @MainActor
    static func makeBackup(context: ModelContext, defaults: UserDefaults = .standard) throws -> BackupFile {
        let products = try context.fetch(FetchDescriptor<Product>())
        let stores = try context.fetch(FetchDescriptor<StoreLocation>())
        let observations = try context.fetch(FetchDescriptor<PriceObservation>())

        return BackupFile(
            format: formatName,
            version: currentVersion,
            exportedAt: .now,
            settings: BackupSettings(
                currencyCode: defaults.string(forKey: "currencyCode") ?? "AMD",
                defaultSource: defaults.string(forKey: "defaultSource") ?? ObservationSource.shelf.rawValue,
                appLanguage: defaults.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue
            ),
            products: products.sorted { $0.createdAt < $1.createdAt }.map { BackupProduct($0) },
            stores: stores.sorted { $0.createdAt < $1.createdAt }.map { BackupStore($0) },
            observations: try observations
                .sorted { $0.observedAt < $1.observedAt }
                .map { try BackupObservation($0) }
        )
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: BackupFile
        do {
            backup = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError(message: "Some records are missing required fields. The file cannot be safely restored.")
        }
        try validate(backup)
        return backup
    }

    static func validate(_ backup: BackupFile) throws {
        guard backup.format == formatName else {
            throw BackupError(message: "This is not a pricemori full backup. CSV exports do not restore the complete journal.")
        }
        guard backup.version == currentVersion else {
            throw BackupError(message: "This backup uses a format version that this version of the app cannot restore.")
        }

        guard validCurrency(backup.settings.currencyCode),
              ObservationSource(rawValue: backup.settings.defaultSource) != nil,
              backup.settings.appLanguage.map({ AppLanguage(rawValue: $0) != nil }) ?? true
        else {
            throw BackupError(message: "The backup contains invalid entry defaults or language settings.")
        }

        let productIDs = Set(backup.products.map(\.id))
        let storeIDs = Set(backup.stores.map(\.id))
        guard productIDs.count == backup.products.count, storeIDs.count == backup.stores.count else {
            throw BackupError(message: "The backup contains duplicate products or stores.")
        }
        guard Set(backup.observations.map(\.id)).count == backup.observations.count else {
            throw BackupError(message: "The backup contains duplicate observations.")
        }

        for product in backup.products where product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BackupError(message: "A product is missing its name.")
        }
        for store in backup.stores where store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw BackupError(message: "A store is missing its name or branch.")
        }

        for observation in backup.observations {
            guard productIDs.contains(observation.productID), storeIDs.contains(observation.storeID) else {
                throw BackupError(message: "An observation refers to a missing product or store.")
            }
            guard let price = observation.decimalPrice, price > 0 else {
                throw BackupError(message: "An observation has an invalid price.")
            }
            guard validCurrency(observation.currencyCode) else {
                throw BackupError(message: "An observation has an invalid currency.")
            }
            guard ObservationCondition(rawValue: observation.condition) != nil,
                  ObservationSource(rawValue: observation.source) != nil
            else {
                throw BackupError(message: "An observation has an unsupported condition or source.")
            }
            if observation.packageQuantity != nil {
                guard let quantity = observation.decimalQuantity, quantity > 0 else {
                    throw BackupError(message: "An observation has an invalid package amount.")
                }
            }
            if let unit = observation.packageUnit,
               MeasurementUnit(rawValue: unit) == nil && MeasurementUnit.fromSymbol(unit) == nil {
                throw BackupError(message: "An observation has an unsupported package unit.")
            }
            if observation.sizeKnown {
                guard let quantity = observation.decimalQuantity, quantity > 0,
                      let unit = observation.packageUnit.flatMap({ MeasurementUnit(rawValue: $0) ?? MeasurementUnit.fromSymbol($0) })
                else {
                    throw BackupError(message: "An observation has a package size that cannot be read.")
                }
                _ = unit
            }
            if observation.condition == ObservationCondition.multiBuy.rawValue {
                guard observation.multiBuyMinimum >= 2 else {
                    throw BackupError(message: "A multi-buy observation has an invalid minimum quantity.")
                }
            }
        }
    }

    private static func validCurrency(_ code: String) -> Bool {
        Locale.commonISOCurrencyCodes.contains(code)
    }

    @MainActor
    static func plan(backup: BackupFile, context: ModelContext) throws -> MergePlan {
        try validate(backup)
        let existingProducts = try context.fetch(FetchDescriptor<Product>())
        let existingStores = try context.fetch(FetchDescriptor<StoreLocation>())
        let existingObservations = try context.fetch(FetchDescriptor<PriceObservation>())

        let productIDs = Set(existingProducts.map(\.id))
        let storeIDs = Set(existingStores.map(\.id))
        let observationsByID = Dictionary(uniqueKeysWithValues: existingObservations.map { ($0.id, $0) })

        let newProducts = backup.products.filter { !productIDs.contains($0.id) }.count
        let newStores = backup.stores.filter { !storeIDs.contains($0.id) }.count

        var newObservations = 0
        var identical = 0
        var conflicts: [ImportConflict] = []

        for observation in backup.observations {
            guard let existing = observationsByID[observation.id] else {
                newObservations += 1
                continue
            }
            let current = try BackupObservation(existing)
            if current == observation {
                identical += 1
            } else {
                conflicts.append(ImportConflict(
                    id: observation.id,
                    productName: existing.product?.displayName ?? "",
                    storeName: existing.store?.displayName ?? "",
                    observedAt: existing.observedAt,
                    current: current,
                    backup: observation
                ))
            }
        }

        return MergePlan(
            backup: backup,
            newProducts: newProducts,
            newStores: newStores,
            newObservations: newObservations,
            identical: identical,
            conflicts: conflicts.sorted { $0.observedAt < $1.observedAt },
            productsAfter: existingProducts.count + newProducts,
            storesAfter: existingStores.count + newStores,
            observationsAfter: existingObservations.count + newObservations
        )
    }

    @MainActor
    static func applyMerge(
        plan: MergePlan,
        choices: [UUID: ConflictChoice],
        context: ModelContext
    ) throws -> ImportResult {
        try validate(plan.backup)
        let productMap = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Product>()).map { ($0.id, $0) })
        let storeMap = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoreLocation>()).map { ($0.id, $0) })
        let observationMap = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<PriceObservation>()).map { ($0.id, $0) })

        var products = productMap
        var stores = storeMap

        do {
            for product in plan.backup.products where products[product.id] == nil {
                let created = Product(
                    id: product.id,
                    name: product.name,
                    brand: product.brand,
                    variety: product.variety,
                    isFavorite: product.isFavorite,
                    isArchived: product.isArchived,
                    archivedAt: product.archivedAt,
                    createdAt: product.createdAt
                )
                context.insert(created)
                products[product.id] = created
            }

            for store in plan.backup.stores where stores[store.id] == nil {
                let created = StoreLocation(
                    id: store.id,
                    name: store.name,
                    branch: store.branch,
                    city: store.city,
                    note: store.note,
                    isArchived: store.isArchived,
                    archivedAt: store.archivedAt,
                    createdAt: store.createdAt
                )
                context.insert(created)
                stores[store.id] = created
            }

            for backup in plan.backup.observations where observationMap[backup.id] == nil {
                guard let product = products[backup.productID], let store = stores[backup.storeID] else {
                    throw BackupError(message: "An observation refers to a missing product or store.")
                }
                guard let created = makeObservation(from: backup, product: product, store: store) else {
                    throw BackupError(message: "The backup contains an observation that cannot be restored.")
                }
                context.insert(created)
            }

            var keptCurrent = 0
            for conflict in plan.conflicts {
                guard let existing = observationMap[conflict.id] else { continue }
                switch choices[conflict.id] ?? .current {
                case .current:
                    keptCurrent += 1
                case .backup:
                    guard let product = products[conflict.backup.productID],
                          let store = stores[conflict.backup.storeID] else {
                        throw BackupError(message: "An observation refers to a missing product or store.")
                    }
                    update(existing, from: conflict.backup)
                    existing.product = product
                    existing.store = store
                }
            }

            try context.save()

            return ImportResult(
                title: "Your journal was merged",
                summary: "\(plan.newObservations) observations added",
                addedObservations: plan.newObservations,
                skippedObservations: plan.identical,
                keptCurrent: keptCurrent,
                products: products.count,
                stores: stores.count,
                observations: observationMap.count + plan.newObservations,
                isReplacement: false
            )
        } catch {
            context.rollback()
            throw BackupError(message: "The journal could not be merged. No changes were kept.")
        }
    }

    @MainActor
    static func replace(with backup: BackupFile, context: ModelContext, defaults: UserDefaults = .standard) throws -> ImportResult {
        try validate(backup)
        do {
            for observation in try context.fetch(FetchDescriptor<PriceObservation>()) {
                context.delete(observation)
            }
            for product in try context.fetch(FetchDescriptor<Product>()) {
                context.delete(product)
            }
            for store in try context.fetch(FetchDescriptor<StoreLocation>()) {
                context.delete(store)
            }

            let products = backup.products.map {
                Product(
                    id: $0.id,
                    name: $0.name,
                    brand: $0.brand,
                    variety: $0.variety,
                    isFavorite: $0.isFavorite,
                    isArchived: $0.isArchived,
                    archivedAt: $0.archivedAt,
                    createdAt: $0.createdAt
                )
            }
            let stores = backup.stores.map {
                StoreLocation(
                    id: $0.id,
                    name: $0.name,
                    branch: $0.branch,
                    city: $0.city,
                    note: $0.note,
                    isArchived: $0.isArchived,
                    archivedAt: $0.archivedAt,
                    createdAt: $0.createdAt
                )
            }
            for product in products { context.insert(product) }
            for store in stores { context.insert(store) }

            let productMap = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            let storeMap = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0) })
            for backupObservation in backup.observations {
                guard let product = productMap[backupObservation.productID],
                      let store = storeMap[backupObservation.storeID],
                      let created = makeObservation(from: backupObservation, product: product, store: store)
                else {
                    throw BackupError(message: "The backup contains an observation that cannot be restored.")
                }
                context.insert(created)
            }

            try context.save()
            defaults.set(backup.settings.currencyCode, forKey: "currencyCode")
            defaults.set(backup.settings.defaultSource, forKey: "defaultSource")
            if let language = backup.settings.appLanguage {
                defaults.set(language, forKey: AppLanguage.storageKey)
            }

            return ImportResult(
                title: "Backup restored in full",
                summary: "Replacement complete",
                addedObservations: backup.observations.count,
                skippedObservations: 0,
                keptCurrent: 0,
                products: backup.products.count,
                stores: backup.stores.count,
                observations: backup.observations.count,
                isReplacement: true
            )
        } catch let error as BackupError {
            context.rollback()
            throw error
        } catch {
            context.rollback()
            throw BackupError(message: "The journal could not be replaced. No changes were kept.")
        }
    }

    private static func makeObservation(from backup: BackupObservation, product: Product, store: StoreLocation) -> PriceObservation? {
        guard let price = backup.decimalPrice,
              let condition = ObservationCondition(rawValue: backup.condition),
              let source = ObservationSource(rawValue: backup.source)
        else { return nil }
        let unit = backup.packageUnit.flatMap { MeasurementUnit(rawValue: $0) ?? MeasurementUnit.fromSymbol($0) }
        return PriceObservation(
            id: backup.id,
            price: price,
            currencyCode: backup.currencyCode,
            observedAt: backup.observedAt,
            createdAt: backup.createdAt,
            updatedAt: backup.updatedAt,
            packageQuantity: backup.decimalQuantity,
            packageUnit: unit,
            sizeKnown: backup.sizeKnown && backup.decimalQuantity != nil,
            isLoose: backup.isLoose,
            condition: condition,
            conditionLabel: backup.conditionLabel,
            conditionEndDate: backup.conditionEndDate,
            multiBuyMinimum: backup.multiBuyMinimum,
            source: source,
            note: backup.note,
            product: product,
            store: store
        )
    }

    private static func update(_ observation: PriceObservation, from backup: BackupObservation) {
        guard let price = backup.decimalPrice,
              let condition = ObservationCondition(rawValue: backup.condition),
              let source = ObservationSource(rawValue: backup.source)
        else { return }
        observation.price = price
        observation.currencyCode = backup.currencyCode
        observation.observedAt = backup.observedAt
        observation.createdAt = backup.createdAt
        observation.updatedAt = backup.updatedAt
        observation.packageQuantity = backup.decimalQuantity
        observation.packageUnit = backup.packageUnit.flatMap { MeasurementUnit(rawValue: $0) ?? MeasurementUnit.fromSymbol($0) }
        observation.sizeKnown = backup.sizeKnown && backup.decimalQuantity != nil
        observation.isLoose = backup.isLoose
        observation.condition = condition
        observation.conditionLabel = backup.conditionLabel
        observation.conditionEndDate = backup.conditionEndDate
        observation.multiBuyMinimum = backup.multiBuyMinimum
        observation.source = source
        observation.note = backup.note
    }
}

enum CSVExport {
    @MainActor
    static func makeData(context: ModelContext) throws -> (data: Data, rows: Int) {
        let observations = try context.fetch(FetchDescriptor<PriceObservation>())
        let headers = [
            "product", "brand", "variety", "store", "branch", "city", "observed_at",
            "price", "currency", "package_quantity", "package_unit", "unit_price", "unit",
            "condition", "condition_label", "source", "note", "created_at", "updated_at",
            "size_known", "is_loose", "multi_buy_minimum", "condition_end_date", "price_basis"
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var lines = [headers.joined(separator: ",")]
        let sorted = observations.sorted { $0.observedAt < $1.observedAt }
        for observation in sorted {
            guard let product = observation.product else { continue }
            let fields: [String] = [
                product.name,
                product.brand,
                product.variety,
                observation.store?.name ?? "",
                observation.store?.branch ?? "",
                observation.store?.city ?? "",
                formatter.string(from: observation.observedAt),
                NSDecimalNumber(decimal: observation.price).stringValue,
                observation.currencyCode,
                observation.packageQuantity.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                observation.packageUnit?.symbol ?? "",
                observation.unitPrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? "",
                observation.baseUnitSymbol ?? "",
                observation.condition.shortTitle,
                observation.conditionLabel,
                observation.source.title,
                observation.note,
                formatter.string(from: observation.createdAt),
                formatter.string(from: observation.updatedAt),
                String(observation.sizeKnown),
                String(observation.isLoose),
                String(observation.multiBuyMinimum),
                observation.conditionEndDate.map(formatter.string(from:)) ?? "",
                observation.condition == .multiBuy ? "total_for_minimum_packages" : (observation.isLoose ? "loose_amount" : "one_package")
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }

        return (Data(lines.joined(separator: "\r\n").utf8), lines.count - 1)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

enum ExportNaming {
    static func short(now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "dd-MMM"
        return formatter.string(from: now)
    }

    static func backup(now: Date = .now) -> String {
        "pricemori-backup-\(short(now: now)).json"
    }

    static func safetyBackup(now: Date = .now) -> String {
        "pricemori-before-restore-\(short(now: now)).json"
    }

    static func csv(now: Date = .now) -> String {
        "pricemori-observations-\(short(now: now)).csv"
    }
}

struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
