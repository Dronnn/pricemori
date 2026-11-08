import SwiftUI
import SwiftData

struct PriceOverTimeView: View {
    let product: Product
    var initialStore: StoreLocation?
    var backLabel: String = "Back"

    @EnvironmentObject private var router: AppRouter
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var selectedStore: StoreLocation?
    @State private var period: ChartPeriod = .month
    @State private var basis: ChartBasis = .unit
    @State private var condition: ObservationCondition = .regular
    @State private var showFilters = false
    @State private var showCustomPeriod = false
    @State private var showRecord = false
    @State private var didResolve = false

    private var activeStores: [StoreLocation] {
        stores.filter { !$0.isArchived }
    }

    private var scopedObservations: [PriceObservation] {
        guard let selectedStore else { return [] }
        let scoped = product.observations.filter {
            $0.store?.id == selectedStore.id && $0.condition == condition
        }
        let currency = scoped.max { ($0.observedAt, $0.createdAt) < ($1.observedAt, $1.createdAt) }?.currencyCode
        let dimension = PriceMath.dominantDimension(for: scoped)
        return scoped
            .filter {
                (currency == nil || $0.currencyCode == currency)
                    && (dimension == nil || $0.packageUnit?.dimension == dimension)
            }
            .sortedChronologically
    }

    private var filteredObservations: [PriceObservation] {
        period.filter(scopedObservations)
    }

    private var current: PriceObservation? {
        scopedObservations.last
    }

    private var change: PriceChange? {
        guard let current else { return nil }
        return PriceMath.change(for: current, among: product.observations)
    }

    private var unitLabel: String {
        if basis == .package { return "package" }
        return scopedObservations.last?.baseUnitSymbol ?? "kg"
    }

    private var range: RecordedRange? {
        PriceMath.allTimeRange(for: filteredObservations)
    }

    private var selectedChange: PriceChange? {
        guard let first = filteredObservations.first, let last = filteredObservations.last, first.id != last.id else { return nil }
        return PriceMath.change(current: last, previous: first)
    }

    var body: some View {
        ScreenScaffold(
            title: "Price over time",
            backLabel: backLabel,
            trailing: {
                Button("Filter") { showFilters = true }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                Text("\(selectedStore?.displayName ?? "") · \(condition.shortTitle) · \(current?.currencyCode ?? "AMD") / \(unitLabel)")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 4)

                if let current {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(Format.number(basis == .unit ? current.headlineAmount : current.effectivePackagePrice, maxFraction: 2))
                            .font(AppFont.serif(32))
                            .foregroundStyle(Theme.primaryText)
                        Text(basis == .unit ? current.headlineUnit : "\(current.currencyCode) / package")
                            .font(AppFont.inter(16))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.top, 16)

                    if let change {
                        Text("\(change.summary) since \(Format.shortDate(change.previous.observedAt))")
                            .font(AppFont.inter(16, .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.top, 4)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "1 month", isSelected: period == .month) { period = .month }
                        FilterChip(title: "3 months", isSelected: period == .threeMonths) { period = .threeMonths }
                        FilterChip(title: "All time", isSelected: period == .all) { period = .all }
                        FilterChip(title: "Custom", isSelected: isCustomPeriod) { showCustomPeriod = true }
                    }
                    .padding(.horizontal, 1)
                }
                .padding(.top, 20)

                if filteredObservations.isEmpty {
                    InfoText(text: "No recorded observations match these filters. No daily values are generated.")
                        .padding(.top, 30)
                } else {
                    PriceChartView(
                        observations: filteredObservations,
                        height: 220,
                        showsUnitLabel: true,
                        basis: basis
                    )
                    .padding(.top, 18)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let first = filteredObservations.first, let last = filteredObservations.last, let range {
                        if let selectedChange {
                            Text("\(Format.number(range.minimum.unitPrice ?? 0, maxFraction: 2)) to \(Format.number(range.maximum.unitPrice ?? 0, maxFraction: 2)) \(current?.currencyCode ?? "AMD") / \(unitLabel) · \(Format.percent(selectedChange.percent))")
                        }
                        Text("Selected period: \(Format.periodRange(from: first.observedAt, to: last.observedAt))\n\(filteredObservations.count) \(filteredObservations.count == 1 ? "observation" : "observations")")
                    } else {
                        Text("Not enough comparable prices in this period.")
                    }
                }
                .font(AppFont.inter(14))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(3)
                .padding(.top, 14)

                if filteredObservations.count < 2 {
                    InfoText(text: "A price change needs two observations with the same branch, currency, units and conditions. One price is still useful without inventing a trend.")
                        .padding(.top, 22)
                    VStack(spacing: 2) {
                        SecondaryButton(title: "Record another observation") { showRecord = true }
                        SecondaryButton(title: "Change chart filters") { showFilters = true }
                    }
                    .padding(.top, 10)
                }

                SecondaryButton(title: "View observation list") {
                    guard let selectedStore else { return }
                    router.push(.history(product, selectedStore, condition))
                }
                .padding(.top, 18)
                .disabled(selectedStore == nil)

                InfoText(text: "Lines connect recorded points; prices between them are unknown.")
                    .padding(.top, 18)
            }
        }
        .onAppear(perform: resolveStore)
        .fullScreenCover(isPresented: $showCustomPeriod) {
            ChartPeriodView(period: $period)
        }
        .fullScreenCover(isPresented: $showFilters) {
            if let selectedStore {
                ChartFiltersView(
                    product: product,
                    stores: activeStores,
                    store: Binding(
                        get: { self.selectedStore ?? selectedStore },
                        set: { self.selectedStore = $0 }
                    ),
                    period: $period,
                    basis: $basis,
                    condition: $condition
                )
            }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordPriceView(product: product, initialStore: selectedStore) { _ in }
        }
    }

    private var isCustomPeriod: Bool {
        if case .custom = period { return true }
        return false
    }

    private func resolveStore() {
        guard !didResolve else { return }
        didResolve = true
        selectedStore = initialStore ?? product.latestRegularObservation?.store ?? activeStores.first
    }
}
