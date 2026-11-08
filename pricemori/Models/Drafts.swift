import Foundation

struct ObservationDraft {
    var priceText: String = ""
    var currencyCode: String = "AMD"
    var quantityText: String = "1"
    var unit: MeasurementUnit = .kilogram
    var sizeKnown: Bool = true
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
        (price ?? 0) > 0
    }

    var hasValidQuantity: Bool {
        !sizeKnown || (quantity ?? 0) > 0
    }

    var unitPricePreview: Decimal? {
        guard hasValidPrice, hasValidQuantity, sizeKnown, let price, let quantity else { return nil }
        let effective = condition == .multiBuy ? price / Decimal(max(1, multiBuyMinimum)) : price
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

    func makeObservation(product: Product, store: StoreLocation) -> PriceObservation? {
        guard hasValidPrice, let price else { return nil }
        guard hasValidQuantity else { return nil }
        let rounded = Format.roundedForCurrency(price, currency: currencyCode)
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
