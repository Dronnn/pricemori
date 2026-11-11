import Foundation

struct ObservationDraft: Equatable {
    var priceText: String = ""
    var currencyCode: String = "AMD"
    var quantityText: String = ""
    var unit: MeasurementUnit = .kilogram
    var sizeKnown: Bool = false
    var isLoose: Bool = false
    var condition: ObservationCondition = .regular
    var conditionLabel: String = ""
    var conditionEndDate: Date?
    var multiBuyMinimum: Int = 1
    var multiBuyTotalText: String = ""
    var source: ObservationSource = .shelf
    var observedAt: Date = .now
    var note: String = ""

    var price: Decimal? {
        Format.decimal(from: priceText)
    }

    var quantity: Decimal? {
        Format.decimal(from: quantityText)
    }

    var hasValidPrice: Bool {
        guard let price, price > 0 else { return false }
        return Format.roundedForCurrency(price, currency: currencyCode) > 0
    }

    var hasValidQuantity: Bool {
        !sizeKnown || (quantity ?? 0) > 0
    }

    var unitPricePreview: Decimal? {
        guard hasValidPrice, hasValidQuantity, sizeKnown, let price, let quantity else { return nil }
        let rounded = Format.roundedForCurrency(price, currency: currencyCode)
        let effective = condition == .multiBuy ? rounded / Decimal(max(2, multiBuyMinimum)) : rounded
        let base = quantity * unit.baseMultiplier
        guard base > 0 else { return nil }
        return effective / base
    }

    var unitPricePreviewText: String? {
        guard let unitPricePreview else { return nil }
        return "\(Format.number(unitPricePreview, maxFraction: 2)) \(currencyCode) / \(unit.baseUnitSymbol)"
    }

    var packageSummary: String {
        guard sizeKnown, let quantity else { return "Package size unknown" }
        let base = "\(Format.quantity(quantity)) \(unit.symbol)"
        return isLoose ? "Loose goods · \(base)" : "\(base) package"
    }

    mutating func applyTemplate(from observation: PriceObservation) {
        currencyCode = observation.currencyCode
        quantityText = observation.packageQuantity.map(Format.inputText) ?? ""
        unit = observation.packageUnit ?? .kilogram
        sizeKnown = observation.sizeKnown
        isLoose = observation.isLoose
        source = observation.source
    }

    /// Suggestions may fill an untouched form, but must not reinterpret entered amounts.
    mutating func suggestTemplate(from observation: PriceObservation, ifUneditedSince baseline: ObservationDraft, at store: StoreLocation) {
        guard self == baseline else { return }
        applyTemplate(from: observation)
        if observation.store?.id == store.id {
            condition = observation.condition
            conditionLabel = observation.conditionLabel
            conditionEndDate = observation.isExpired ? nil : observation.conditionEndDate
            multiBuyMinimum = observation.multiBuyMinimum
        } else {
            condition = .regular
            conditionLabel = ""
            conditionEndDate = nil
            multiBuyMinimum = 1
        }
    }

    func makeObservation(product: Product, store: StoreLocation) -> PriceObservation? {
        guard hasValidPrice, let price else { return nil }
        guard hasValidQuantity else { return nil }
        let rounded = Format.roundedForCurrency(price, currency: currencyCode)
        guard rounded > 0 else { return nil }
        let quantity = sizeKnown ? self.quantity : nil
        return PriceObservation(
            price: rounded,
            currencyCode: currencyCode,
            observedAt: observedAt,
            packageQuantity: quantity,
            packageUnit: quantity == nil ? nil : unit,
            sizeKnown: sizeKnown && quantity != nil,
            isLoose: isLoose,
            condition: condition,
            conditionLabel: condition == .card ? conditionLabel : "",
            conditionEndDate: condition == .card ? conditionEndDate : nil,
            multiBuyMinimum: condition == .multiBuy ? max(2, multiBuyMinimum) : 1,
            source: source,
            note: note,
            product: product,
            store: store
        )
    }

    @discardableResult
    func applyCorrection(to observation: PriceObservation, product: Product? = nil, store: StoreLocation? = nil) -> Bool {
        guard hasValidPrice, hasValidQuantity, let price else { return false }
        if let product { observation.product = product }
        if let store { observation.store = store }
        observation.price = Format.roundedForCurrency(price, currency: currencyCode)
        observation.currencyCode = currencyCode
        observation.observedAt = observedAt
        observation.packageQuantity = sizeKnown ? quantity : nil
        observation.packageUnit = sizeKnown ? unit : nil
        observation.sizeKnown = sizeKnown
        observation.isLoose = isLoose
        observation.condition = condition
        observation.conditionLabel = condition == .card ? conditionLabel : ""
        observation.conditionEndDate = condition == .card ? conditionEndDate : nil
        observation.multiBuyMinimum = condition == .multiBuy ? max(2, multiBuyMinimum) : 1
        observation.source = source
        observation.note = note
        observation.updatedAt = .now
        return true
    }
}

struct ProductDraft {
    var name: String = ""
    var brand: String = ""
    var variety: String = ""
    var isFavorite: Bool = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayName: String {
        [name, brand].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }

    mutating func parseCombinedName() {
        guard brand.trimmingCharacters(in: .whitespaces).isEmpty,
              let separator = name.range(of: " · ")
        else { return }
        let original = name
        name = String(original[..<separator.lowerBound]).trimmingCharacters(in: .whitespaces)
        brand = String(original[separator.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    func makeProduct() -> Product {
        Product(name: name.trimmingCharacters(in: .whitespacesAndNewlines), brand: brand.trimmingCharacters(in: .whitespaces), variety: variety.trimmingCharacters(in: .whitespaces), isFavorite: isFavorite)
    }
}
