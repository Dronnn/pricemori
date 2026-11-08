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

    static func comparable(_ lhs: PriceObservation, _ rhs: PriceObservation) -> Bool {
        guard lhs.currencyCode == rhs.currencyCode else { return false }
        guard lhs.condition == rhs.condition else { return false }
        if lhs.condition == .card {
            let leftLabel = lhs.conditionLabel.trimmingCharacters(in: .whitespaces).lowercased()
            let rightLabel = rhs.conditionLabel.trimmingCharacters(in: .whitespaces).lowercased()
            guard leftLabel == rightLabel else { return false }
        }
        guard let leftUnit = lhs.packageUnit, let rightUnit = rhs.packageUnit else { return false }
        guard leftUnit.dimension == rightUnit.dimension else { return false }
        if leftUnit.dimension == .count, leftUnit != rightUnit { return false }
        guard lhs.unitPrice != nil, rhs.unitPrice != nil else { return false }
        return true
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
            if left.unitPrice != nil, right.unitPrice != nil {
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
        dimension: UnitDimension? = nil
    ) -> [PriceObservation] {
        product.observations
            .filter { observation in
                observation.store?.id == store.id
                    && observation.condition == condition
                    && (currency == nil || observation.currencyCode == currency)
                    && observation.unitPrice != nil
                    && (dimension == nil || observation.packageUnit?.dimension == dimension)
            }
            .sorted { isEarlier($0, than: $1) }
    }

    static func dominantDimension(for observations: [PriceObservation]) -> UnitDimension? {
        observations
            .compactMap { $0.packageUnit?.dimension }
            .reduce(into: [UnitDimension: Int]()) { $0[$1, default: 0] += 1 }
            .max { $0.value < $1.value }?
            .key
    }

    static func allTimeRange(for observations: [PriceObservation]) -> RecordedRange? {
        let priced = observations.filter { $0.unitPrice != nil }
        guard let minimum = priced.min(by: { ($0.unitPrice ?? 0) < ($1.unitPrice ?? 0) }),
              let maximum = priced.max(by: { ($0.unitPrice ?? 0) < ($1.unitPrice ?? 0) }),
              let latest = priced.max(by: { isEarlier($0, than: $1) })
        else { return nil }
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
            let observations = product.observations
                .filter { observation in
                    observation.store?.id == store.id
                        && observation.condition == condition
                        && observation.currencyCode == currency
                        && observation.observedAt >= start
                        && observation.observedAt < end
                        && observation.unitPrice != nil
                }
                .sorted { isEarlier($0, than: $1) }
            guard let first = observations.first,
                  let last = observations.last,
                  first.id != last.id,
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
