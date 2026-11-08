import SwiftUI

struct CompareStoresView: View {
    enum Tab {
        case regular
        case conditional
        case excluded
    }

    let product: Product

    @EnvironmentObject private var router: AppRouter
    @State private var tab: Tab = .regular
    @State private var selectedOffer: PriceObservation?

    private var currency: String {
        product.latestRegularObservation?.currencyCode ?? "AMD"
    }

    private var dimension: UnitDimension? {
        PriceMath.dominantDimension(for: product.regularObservations)
    }

    private var storePrices: [StorePrice] {
        PriceMath.latestPerStore(for: product, condition: .regular, currency: currency)
            .filter { item in
                guard let dimension else { return item.observation.unitPrice != nil }
                return item.observation.packageUnit?.dimension == dimension && item.observation.unitPrice != nil
            }
            .sorted { $0.observation.observedAt > $1.observation.observedAt }
    }

    private var conditionalOffers: [PriceObservation] {
        Array(product.observations
            .filter { $0.condition != .regular && !$0.isExpired }
            .sortedChronologically
            .reversed())
    }

    private var excluded: [PriceObservation] {
        product.regularObservations.filter { observation in
            if observation.currencyCode != currency { return true }
            if observation.unitPrice == nil { return true }
            if let dimension, observation.packageUnit?.dimension != dimension { return true }
            return false
        }
    }

    private var unitLabel: String {
        storePrices.first?.observation.baseUnitSymbol ?? "kg"
    }

    private var maximumPrice: Decimal {
        storePrices.compactMap(\.unitPrice).max() ?? 1
    }

    var body: some View {
        ScreenScaffold(
            title: "Compare stores",
            backLabel: "Back",
            footer: {
                SecondaryButton(title: "Compare store histories") {
                    router.push(.storeHistories(product))
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.displayName)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                HStack(spacing: 8) {
                    FilterChip(title: "Regular", isSelected: tab == .regular) { tab = .regular }
                    FilterChip(title: "Conditional", isSelected: tab == .conditional) { tab = .conditional }
                    FilterChip(title: "Excluded · \(excluded.count)", isSelected: tab == .excluded) { tab = .excluded }
                }

                switch tab {
                case .regular:
                    regularContent
                case .conditional:
                    conditionalContent
                case .excluded:
                    excludedContent
                }
            }
        }
        .fullScreenCover(item: $selectedOffer) { offer in
            OfferDetailView(product: product, observation: offer)
        }
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Last known unit prices · \(currency) / \(unitLabel)")
                .font(AppFont.inter(14))
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, 20)

            VStack(spacing: 0) {
                ForEach(storePrices, id: \.store.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.store.displayName)
                                .font(AppFont.inter(15))
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text(item.unitPrice.map { Format.number($0, maxFraction: 2) } ?? "")
                                .font(AppFont.inter(19, .semibold))
                                .foregroundStyle(Theme.primaryText)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.separator.opacity(0.45))
                                Capsule()
                                    .fill(Theme.chartLine)
                                    .frame(width: geometry.size.width * ratio(for: item))
                            }
                        }
                        .frame(height: 10)
                        Text(stalenessLine(item))
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 14)
                }
            }

            if let lowest = storePrices.min(by: { ($0.unitPrice ?? 0) < ($1.unitPrice ?? 0) }), let unitPrice = lowest.unitPrice {
                InfoText(text: "Lowest last known: \(Format.number(unitPrice, maxFraction: 2)) \(currency) / \(unitLabel), recorded \(Format.relativeAge(lowest.observation.observedAt).lowercased()). Confirm the price before travelling.")
                    .padding(.top, 16)
            }
        }
    }

    private var conditionalContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Card and multi-buy offers · \(currency)")
                .font(AppFont.inter(14))
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, 20)

            if conditionalOffers.isEmpty {
                InfoText(text: "No card or multi-buy offers are recorded for this product.")
                    .padding(.top, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(conditionalOffers) { offer in
                        Button {
                            selectedOffer = offer
                        } label: {
                            OfferRow(observation: offer)
                        }
                        .buttonStyle(.plain)
                        SeparatorLine()
                    }
                }
            }

            InfoText(text: "Offers are separated by eligibility and minimum quantity. Regular prices stay in their own comparison.")
                .padding(.top, 18)
        }
    }

    private var excludedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Why some prices are separate")
                .font(AppFont.inter(16, .medium))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 20)

            VStack(spacing: 0) {
                ForEach(excluded) { observation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exclusionTitle(observation))
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Text(exclusionDetail(observation))
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                        Text("\(observation.store?.displayName ?? "") · \(Format.date(observation.observedAt))")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    SeparatorLine()
                }
            }

            InfoText(text: "No missing prices are guessed. Excluded observations remain visible in history.")
                .padding(.top, 18)
        }
    }

    private func ratio(for item: StorePrice) -> CGFloat {
        guard maximumPrice > 0, let price = item.unitPrice else { return 0 }
        return max(0.03, CGFloat(NSDecimalNumber(decimal: price / maximumPrice).doubleValue))
    }

    private func stalenessLine(_ item: StorePrice) -> String {
        let age = Format.relativeAge(item.observation.observedAt)
        let package = item.observation.packageSummary
        let suffix = age.contains("days ago") ? " · May have changed" : ""
        return "\(Format.date(item.observation.observedAt)) · \(age) · \(package)\(suffix)"
    }

    private func exclusionTitle(_ observation: PriceObservation) -> String {
        if observation.currencyCode != currency {
            return "Different currency · \(Format.money(observation.price, currency: observation.currencyCode)) \(observation.currencyCode)"
        }
        if observation.unitPrice == nil {
            return "Unknown package size · \(Format.money(observation.price, currency: observation.currencyCode)) \(observation.currencyCode)"
        }
        return "Incompatible basis · \(observation.packageUnit?.symbol ?? "unit")"
    }

    private func exclusionDetail(_ observation: PriceObservation) -> String {
        if observation.currencyCode != currency {
            return "No exchange rate is applied. Currency must match to rank prices."
        }
        if observation.unitPrice == nil {
            return "Price per \(unitLabel) cannot be calculated. Keep this as a package-price observation."
        }
        return "Items cannot be converted to \(unitLabel) without a known equivalent."
    }
}
