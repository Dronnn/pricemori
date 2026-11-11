import Foundation

extension PriceObservation {
    /// Price shown as the headline: normalized unit price when the package size is known.
    var headlineAmount: Decimal {
        unitPrice ?? effectivePackagePrice
    }

    var headlineUnit: String {
        if unitPrice != nil, let unit = baseUnitSymbol { return "\(currencyCode) / \(unit)" }
        return currencyCode
    }

    /// The package price line used in lists, e.g. "300 AMD / 1 kg".
    var packagePriceLine: String {
        let amount = Format.money(effectivePackagePrice, currency: currencyCode)
        if condition == .multiBuy {
            let package = packageSummary.lowercased()
            return "\(Format.money(price, currency: currencyCode)) \(currencyCode) / \(multiBuyMinimum) × \(package)"
        }
        guard sizeKnown, let packageQuantity, let packageUnit else {
            return L10n.format("%@ %@ / package", amount, currencyCode)
        }
        if packageUnit.dimension == .count, packageQuantity == 1 {
            return "\(amount) \(currencyCode) / \(packageUnit.symbol)"
        }
        return "\(amount) \(currencyCode) / \(Format.quantity(packageQuantity)) \(packageUnit.symbol)"
    }

    /// The normalized unit price line, e.g. "320 AMD / kg".
    var unitPriceLine: String? {
        guard let unitPrice, let unit = baseUnitSymbol else { return nil }
        return "\(Format.number(unitPrice, maxFraction: 2)) \(currencyCode) / \(unit)"
    }

    var unitPriceValueLine: String {
        unitPriceLine ?? packagePriceLine
    }

    var conditionLine: String {
        switch condition {
        case .regular:
            return L10n.string("Regular")
        case .card:
            return conditionLabel.isEmpty ? L10n.string("Card required") : conditionLabel
        case .multiBuy:
            return L10n.format("Multi-buy · %lld packages", multiBuyMinimum)
        }
    }

    var detailMetaLine: String {
        [packageSummary, source.shortTitle, condition == .regular ? nil : conditionLine]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var isExpired: Bool {
        guard let conditionEndDate else { return false }
        return conditionEndDate < Calendar.current.startOfDay(for: .now)
    }
}

extension Array where Element == PriceObservation {
    var sortedChronologically: [PriceObservation] {
        sorted { lhs, rhs in
            if lhs.observedAt == rhs.observedAt { return lhs.createdAt < rhs.createdAt }
            return lhs.observedAt < rhs.observedAt
        }
    }
}
