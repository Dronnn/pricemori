import Foundation

struct PriceChange {
    let amount: Decimal
    let percent: Decimal
    let previous: PriceObservation
    let current: PriceObservation
    let unitLabel: String

    var amountText: String {
        Format.signedMoney(amount, currency: current.currencyCode, unit: unitLabel)
    }

    var summary: String {
        "\(amountText) · \(Format.percent(percent))"
    }
}

struct StorePrice {
    let store: StoreLocation
    let observation: PriceObservation

    var unitPrice: Decimal? { observation.unitPrice }
}

struct RecordedRange {
    let minimum: PriceObservation
    let maximum: PriceObservation
    let latest: PriceObservation
}

struct PeriodChangeRow: Identifiable {
    let product: Product
    let first: PriceObservation
    let last: PriceObservation
    let change: PriceChange

    var id: UUID { product.id }
}

enum PriceMath {
    private static func sortKey(_ observation: PriceObservation) -> (Date, Date) {
        (observation.observedAt, observation.createdAt)
    }

    static func isEarlier(_ lhs: PriceObservation, than rhs: PriceObservation) -> Bool {
        let left = sortKey(lhs)
        let right = sortKey(rhs)
        if left.0 == right.0 { return left.1 < right.1 }
        return left.0 < right.0
    }

    static func sameConditions(_ lhs: PriceObservation, _ rhs: PriceObservation) -> Bool {
        guard lhs.condition == rhs.condition else { return false }
        if lhs.condition == .card {
            let leftLabel = lhs.conditionLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let rightLabel = rhs.conditionLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard leftLabel == rightLabel else { return false }
        }
        if lhs.condition == .multiBuy, lhs.multiBuyMinimum != rhs.multiBuyMinimum { return false }
        return true
    }

    static func compatibleUnits(_ lhs: PriceObservation, _ rhs: PriceObservation) -> Bool {
        guard let leftUnit = lhs.packageUnit, let rightUnit = rhs.packageUnit else { return false }
        guard leftUnit.dimension == rightUnit.dimension else { return false }
        if leftUnit.dimension == .count, leftUnit != rightUnit { return false }
        return true
    }

    static func sameOffer(_ lhs: PriceObservation, _ rhs: PriceObservation) -> Bool {
        sameConditions(lhs, rhs)
    }

    static func comparable(_ lhs: PriceObservation, _ rhs: PriceObservation) -> Bool {
        lhs.currencyCode == rhs.currencyCode
            && sameConditions(lhs, rhs)
            && compatibleUnits(lhs, rhs)
            && lhs.unitPrice != nil && rhs.unitPrice != nil
    }

    static func previousComparable(for observation: PriceObservation, among observations: [PriceObservation]) -> PriceObservation? {
        observations
            .filter { candidate in
                candidate.id != observation.id
                    && candidate.store?.id == observation.store?.id
                    && isEarlier(candidate, than: observation)
                    && comparable(candidate, observation)
            }
            .max { isEarlier($0, than: $1) }
    }

    static func nextComparable(for observation: PriceObservation, among observations: [PriceObservation]) -> PriceObservation? {
        observations
            .filter { candidate in
                candidate.id != observation.id
                    && candidate.store?.id == observation.store?.id
                    && isEarlier(observation, than: candidate)
                    && comparable(candidate, observation)
            }
            .min { isEarlier($0, than: $1) }
    }

    static func change(current: PriceObservation, previous: PriceObservation) -> PriceChange? {
        guard comparable(previous, current),
              let previousUnit = previous.unitPrice,
              let currentUnit = current.unitPrice,
              let unit = current.baseUnitSymbol
        else { return nil }
        let amount = currentUnit - previousUnit
        guard previousUnit != 0 else { return nil }
        let percent = (amount / previousUnit) * 100
        return PriceChange(
            amount: amount,
            percent: percent,
            previous: previous,
            current: current,
            unitLabel: unit
        )
    }

    static func change(for observation: PriceObservation, among observations: [PriceObservation]) -> PriceChange? {
        guard let previous = previousComparable(for: observation, among: observations) else { return nil }
        return change(current: observation, previous: previous)
    }

    static func latestObservation(for product: Product, condition: ObservationCondition = .regular) -> PriceObservation? {
        product.observations
            .filter { $0.condition == condition }
            .max { isEarlier($0, than: $1) }
    }

    static func latestObservation(for product: Product, store: StoreLocation, condition: ObservationCondition = .regular) -> PriceObservation? {
        product.observations
            .filter { $0.store?.id == store.id && $0.condition == condition }
            .max { isEarlier($0, than: $1) }
    }

    /// One known unit basis shared by every branch in a cross-store comparison.
    static func crossStoreReference(for product: Product, currency: String? = nil) -> PriceObservation? {
        let active = product.regularObservations.filter { $0.store?.isArchived == false }
        let selectedCurrency = currency ?? active.last?.currencyCode
        return active.last { $0.currencyCode == selectedCurrency && $0.unitPrice != nil }
    }

    static func latestPerStore(
        for product: Product,
        condition: ObservationCondition = .regular,
        currency: String? = nil
    ) -> [StorePrice] {
        var result: [UUID: StorePrice] = [:]
        for observation in product.observations where observation.condition == condition {
            guard let store = observation.store else { continue }
            if let currency, observation.currencyCode != currency { continue }
            if let existing = result[store.id] {
                if isEarlier(existing.observation, than: observation) {
                    result[store.id] = StorePrice(store: store, observation: observation)
                }
            } else {
                result[store.id] = StorePrice(store: store, observation: observation)
            }
        }
        return result.values.sorted { lhs, rhs in
            let left = lhs.observation
            let right = rhs.observation
            if sortKey(left) != sortKey(right) {
                return isEarlier(right, than: left)
            }
            return lhs.store.displayName.localizedCaseInsensitiveCompare(rhs.store.displayName) == .orderedAscending
        }
    }

    static func series(
        for product: Product,
        store: StoreLocation,
        condition: ObservationCondition = .regular,
        currency: String? = nil,
        dimension: UnitDimension? = nil,
        reference: PriceObservation? = nil,
        includeUnknownSize: Bool = false
    ) -> [PriceObservation] {
        let candidates = product.observations
            .filter { observation in
                observation.store?.id == store.id
                    && observation.condition == condition
                    && (currency == nil || observation.currencyCode == currency)
                    && (dimension == nil || observation.packageUnit?.dimension == dimension || (includeUnknownSize && observation.unitPrice == nil))
            }
            .sorted { isEarlier($0, than: $1) }
        guard let anchor = reference ?? candidates.last else { return [] }
        let scoped = candidates.filter {
            $0.currencyCode == anchor.currencyCode && sameConditions($0, anchor)
        }
        // An unknown-size last observation must not erase earlier compatible unit history.
        let unitAnchor = anchor.unitPrice != nil ? anchor : scoped.last { $0.unitPrice != nil }
        return scoped.filter { observation in
            if observation.unitPrice == nil { return includeUnknownSize }
            guard let unitAnchor else { return false }
            return comparable(observation, unitAnchor)
        }
    }

    static func dominantDimension(for observations: [PriceObservation]) -> UnitDimension? {
        observations
            .compactMap { $0.packageUnit?.dimension }
            .reduce(into: [UnitDimension: Int]()) { $0[$1, default: 0] += 1 }
            .max { $0.value < $1.value }?
            .key
    }

    static func allTimeRange(for observations: [PriceObservation]) -> RecordedRange? {
        var minimum: PriceObservation?
        var maximum: PriceObservation?
        var latest: PriceObservation?

        for observation in observations {
            guard let price = observation.unitPrice else { continue }
            if let current = minimum, let currentPrice = current.unitPrice {
                if price < currentPrice { minimum = observation }
            } else {
                minimum = observation
            }
            if let current = maximum, let currentPrice = current.unitPrice {
                if price > currentPrice { maximum = observation }
            } else {
                maximum = observation
            }
            if let current = latest {
                if isEarlier(current, than: observation) { latest = observation }
            } else {
                latest = observation
            }
        }

        guard let minimum, let maximum, let latest else { return nil }
        return RecordedRange(minimum: minimum, maximum: maximum, latest: latest)
    }

    static func periodChanges(
        products: [Product],
        store: StoreLocation,
        from: Date,
        to: Date,
        currency: String,
        condition: ObservationCondition = .regular
    ) -> [PeriodChangeRow] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) ?? to

        return products.compactMap { product in
            let inPeriod = product.observations.filter {
                $0.store?.id == store.id && $0.condition == condition
                    && $0.currencyCode == currency && $0.observedAt >= start && $0.observedAt < end
                    && $0.unitPrice != nil
            }.sorted { isEarlier($0, than: $1) }
            guard let anchor = inPeriod.last else { return nil }
            let comparableObservations = inPeriod.filter { comparable($0, anchor) }
            let first = comparableObservations.first
            let last = comparableObservations.last
            guard let first, let last, first.id != last.id,
                  let change = change(current: last, previous: first)
            else { return nil }
            return PeriodChangeRow(product: product, first: first, last: last, change: change)
        }
        .sorted { $0.product.createdAt < $1.product.createdAt }
    }

    static func excludedObservations(for product: Product, currency: String, dimension: UnitDimension?) -> [PriceObservation] {
        product.observations.filter { observation in
            if observation.currencyCode != currency { return true }
            if observation.unitPrice == nil { return true }
            if let dimension, observation.packageUnit?.dimension != dimension { return true }
            return false
        }
    }

    static func latestCurrency(for product: Product) -> String {
        latestObservation(for: product)?.currencyCode ?? "AMD"
    }

    static func latestStore(for product: Product) -> StoreLocation? {
        latestObservation(for: product)?.store
    }
}
