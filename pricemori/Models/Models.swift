import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var variety: String = ""
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var archivedAt: Date?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \PriceObservation.product)
    var observations: [PriceObservation] = []

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        variety: String = "",
        isFavorite: Bool = false,
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.variety = variety
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    var displayName: String {
        [name, brand].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }

    var detailLine: String {
        [brand, variety].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }

    var searchText: String {
        [name, brand, variety].joined(separator: " ").lowercased()
    }

    var sortedObservations: [PriceObservation] {
        observations.sorted { lhs, rhs in
            if lhs.observedAt == rhs.observedAt { return lhs.createdAt < rhs.createdAt }
            return lhs.observedAt < rhs.observedAt
        }
    }

    var regularObservations: [PriceObservation] {
        sortedObservations.filter { $0.condition == .regular }
    }

    var latestRegularObservation: PriceObservation? {
        observations
            .filter { $0.condition == .regular }
            .max { lhs, rhs in
                if lhs.observedAt == rhs.observedAt { return lhs.createdAt < rhs.createdAt }
                return lhs.observedAt < rhs.observedAt
            }
    }

    var storeCount: Int {
        Set(observations.compactMap { $0.store?.id }).count
    }

    var sortedStores: [StoreLocation] {
        Dictionary(grouping: observations.compactMap(\.store), by: \.id)
            .compactMap { $0.value.first }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

@Model
final class StoreLocation {
    var id: UUID = UUID()
    var name: String = ""
    var branch: String = ""
    var city: String = ""
    var note: String = ""
    var isArchived: Bool = false
    var archivedAt: Date?
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \PriceObservation.store)
    var observations: [PriceObservation] = []

    init(
        id: UUID = UUID(),
        name: String,
        branch: String,
        city: String = "",
        note: String = "",
        isArchived: Bool = false,
        archivedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.branch = branch
        self.city = city
        self.note = note
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    var displayName: String {
        [name, branch].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }

    var detailLine: String {
        [city, note].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }

    var sortedObservations: [PriceObservation] {
        observations.sorted { $0.observedAt > $1.observedAt }
    }

    var latestObservation: PriceObservation? {
        observations.max { lhs, rhs in
            if lhs.observedAt == rhs.observedAt { return lhs.createdAt < rhs.createdAt }
            return lhs.observedAt < rhs.observedAt
        }
    }

    var productCount: Int {
        Set(observations.compactMap { $0.product?.id }).count
    }

    var sortedProducts: [Product] {
        Dictionary(grouping: observations.compactMap(\.product), by: \.id)
            .compactMap { $0.value.first }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class PriceObservation {
    var id: UUID = UUID()
    var price: Decimal = 0
    var currencyCode: String = "AMD"
    var observedAt: Date = Date.now
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// Package size for one package, or the weighed amount for a loose price.
    var packageQuantity: Decimal?
    var packageUnitRaw: String?
    var sizeKnown: Bool = true
    var isLoose: Bool = false

    var conditionRaw: String = ObservationCondition.regular.rawValue
    var conditionLabel: String = ""
    var conditionEndDate: Date?
    var multiBuyMinimum: Int = 1

    var sourceRaw: String = ObservationSource.shelf.rawValue
    var note: String = ""

    var product: Product?
    var store: StoreLocation?

    init(
        id: UUID = UUID(),
        price: Decimal,
        currencyCode: String,
        observedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        packageQuantity: Decimal? = 1,
        packageUnit: MeasurementUnit? = .kilogram,
        sizeKnown: Bool = true,
        isLoose: Bool = false,
        condition: ObservationCondition = .regular,
        conditionLabel: String = "",
        conditionEndDate: Date? = nil,
        multiBuyMinimum: Int = 1,
        source: ObservationSource = .shelf,
        note: String = "",
        product: Product? = nil,
        store: StoreLocation? = nil
    ) {
        self.id = id
        self.price = price
        self.currencyCode = currencyCode
        self.observedAt = observedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.packageQuantity = packageQuantity
        self.packageUnitRaw = packageUnit?.rawValue
        self.sizeKnown = sizeKnown
        self.isLoose = isLoose
        self.conditionRaw = condition.rawValue
        self.conditionLabel = conditionLabel
        self.conditionEndDate = conditionEndDate
        self.multiBuyMinimum = multiBuyMinimum
        self.sourceRaw = source.rawValue
        self.note = note
        self.product = product
        self.store = store
    }

    var condition: ObservationCondition {
        get { ObservationCondition(rawValue: conditionRaw) ?? .regular }
        set { conditionRaw = newValue.rawValue }
    }

    var source: ObservationSource {
        get { ObservationSource(rawValue: sourceRaw) ?? .shelf }
        set { sourceRaw = newValue.rawValue }
    }

    var packageUnit: MeasurementUnit? {
        get { packageUnitRaw.flatMap { MeasurementUnit(rawValue: $0) ?? MeasurementUnit.fromSymbol($0) } }
        set { packageUnitRaw = newValue?.rawValue }
    }

    /// One package amount when a multi-buy total is recorded.
    var effectivePackagePrice: Decimal {
        condition == .multiBuy ? price / Decimal(max(1, multiBuyMinimum)) : price
    }

    var baseQuantity: Decimal? {
        guard sizeKnown, let packageQuantity, let packageUnit, packageQuantity > 0 else { return nil }
        return packageQuantity * packageUnit.baseMultiplier
    }

    var unitPrice: Decimal? {
        guard let baseQuantity, baseQuantity > 0 else { return nil }
        return effectivePackagePrice / baseQuantity
    }

    var baseUnitSymbol: String? {
        packageUnit?.baseUnitSymbol
    }

    var packageSummary: String {
        guard sizeKnown, let packageQuantity, let packageUnit else {
            return L10n.string("Package size unknown")
        }
        let amount = Format.quantity(packageQuantity)
        let base = "\(amount) \(packageUnit.symbol)"
        if isLoose {
            return L10n.format("Loose goods · %@", base)
        }
        if packageUnit.dimension == .count {
            return base
        }
        return L10n.format("%@ package", base)
    }

    var conditionSummary: String {
        switch condition {
        case .regular:
            return L10n.string("Regular")
        case .card:
            return conditionLabel.isEmpty ? L10n.string("Card required") : conditionLabel
        case .multiBuy:
            return L10n.format("%lld × %@", multiBuyMinimum, packageSummary)
        }
    }

    var sourceSummary: String {
        source.shortTitle
    }

    var multiBuySummary: String {
        guard condition == .multiBuy else { return "" }
        let each = effectivePackagePrice
        let package = packageSummary.replacingOccurrences(of: L10n.string("package"), with: "").trimmingCharacters(in: .whitespaces)
        return L10n.format(
            "%lld × %@ for %@ %@ total · %@ %@ each",
            multiBuyMinimum,
            package,
            Format.money(price, currency: currencyCode),
            currencyCode,
            Format.money(each, currency: currencyCode),
            currencyCode
        )
    }
}
