import SwiftUI
import SwiftData

enum ChartBasis: String, CaseIterable, Identifiable {
    case unit
    case package

    var id: String { rawValue }
    var title: String { self == .unit ? "Per unit" : "Package price" }

    static func preferred(for observation: PriceObservation?) -> ChartBasis {
        observation?.unitPrice == nil ? .package : .unit
    }
}

enum ChartPeriod: Equatable {
    case month
    case threeMonths
    case all
    case custom(from: Date, to: Date)

    var title: String {
        switch self {
        case .month: "1 month"
        case .threeMonths: "3 months"
        case .all: "All time"
        case .custom: "Custom"
        }
    }

    func range(reference: Date = .now) -> ClosedRange<Date>? {
        let calendar = Calendar.current
        func endOfDay(_ date: Date) -> Date {
            let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
            return next.addingTimeInterval(-1)
        }
        switch self {
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: reference)) ?? reference
            return start...endOfDay(reference)
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: calendar.startOfDay(for: reference)) ?? reference
            return start...endOfDay(reference)
        case .all:
            return nil
        case .custom(let from, let to):
            let start = calendar.startOfDay(for: min(from, to))
            return start...endOfDay(max(from, to))
        }
    }

    func filter(_ observations: [PriceObservation], reference: Date = .now) -> [PriceObservation] {
        guard let range = range(reference: reference) else { return observations }
        return observations.filter { range.contains($0.observedAt) }
    }

    func displayTitle(reference: Date = .now) -> String {
        guard let range = range(reference: reference) else { return "All time" }
        return Format.periodRange(from: range.lowerBound, to: range.upperBound)
    }
}

struct StatisticsView: View {
    var preferredProduct: Product?
    var preferredStore: StoreLocation?

    @EnvironmentObject private var router: AppRouter
    @Query(sort: \Product.createdAt) private var products: [Product]
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var selectedProduct: Product?
    @State private var selectedStore: StoreLocation?
    @State private var showScope = false
    @State private var didResolve = false

    init(preferredProduct: Product? = nil, preferredStore: StoreLocation? = nil) {
        self.preferredProduct = preferredProduct
        self.preferredStore = preferredStore
        _selectedProduct = State(initialValue: preferredProduct)
        _selectedStore = State(initialValue: preferredStore)
    }

    private var reference: PriceObservation? {
        guard let selectedProduct, let selectedStore else { return nil }
        return selectedProduct.observations.filter { $0.store?.id == selectedStore.id }
            .max { PriceMath.isEarlier($0, than: $1) }
    }

    private var currency: String { reference?.currencyCode ?? "" }
    private var basis: ChartBasis { .preferred(for: reference) }
    private var observations: [PriceObservation] {
        guard let selectedProduct, let selectedStore, let reference else { return [] }
        return PriceMath.series(for: selectedProduct, store: selectedStore, condition: reference.condition,
                                currency: currency, reference: reference, includeUnknownSize: basis == .package)
    }
    private var range: ClosedRange<Decimal>? { ChartValues.range(observations, basis: basis) }
    private var periodChange: Decimal? { ChartValues.percentChange(observations, basis: basis) }
    private var unitLabel: String { basis == .package ? "package" : reference?.baseUnitSymbol ?? "unit" }

    var body: some View {
        ScreenScaffold(title: "Statistics", backLabel: "Back", topPadding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("How are my prices\nchanging?")
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let product = selectedProduct, let store = selectedStore {
                    Text("\(product.name) · \(store.displayName)")
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                        .padding(.top, 18)
                    HStack(spacing: 6) {
                        Text("\(reference?.conditionLine ?? "") · \(currency) / \(unitLabel)")
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                        Button(action: { showScope = true }) {
                            Text("Change scope")
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                } else {
                    InfoText(text: "Record a price to see statistics.")
                        .padding(.top, 18)
                }

                if !observations.isEmpty, let product = selectedProduct, let store = selectedStore, let reference {
                    NavigationLink(value: AppRoute.scopedPriceOverTime(product, store, reference.id)) {
                        PriceChartView(observations: observations, height: 220, showsUnitLabel: true, basis: basis)
                            .padding(.top, 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("statistics-price-chart")

                    SecondaryButton(title: "Explore price history") {
                        router.push(.scopedPriceOverTime(product, store, reference.id))
                    }

                    if let first = observations.first, let last = observations.last, let range {
                        VStack(alignment: .leading, spacing: 4) {
                            if let periodChange {
                                Text("\(Format.number(range.lowerBound, maxFraction: 2)) to \(Format.number(range.upperBound, maxFraction: 2)) \(currency) / \(unitLabel) · \(Format.percent(periodChange))")
                            } else {
                                Text("One observation · \(Format.number(ChartValues.amount(last, basis: basis) ?? 0, maxFraction: 2)) \(currency) / \(unitLabel)")
                            }
                            Text("\(Format.periodRange(from: first.observedAt, to: last.observedAt)) · \(observations.count) \(observations.count == 1 ? "observation" : "observations")")
                        }
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 12)
                    }
                } else if selectedProduct != nil, selectedStore != nil {
                    InfoText(text: "No recorded prices at this branch yet.")
                        .padding(.top, 24)
                }

                VStack(spacing: 2) {
                    if let selectedProduct {
                        SecondaryButton(title: "Where was it cheapest?") { router.push(.compareStores(selectedProduct)) }
                    }
                    SecondaryButton(title: "Which products changed most?") {
                        router.push(.periodChanges(selectedStore))
                    }
                    if let selectedProduct {
                        SecondaryButton(title: "More ways to compare") { router.push(.moreComparisons(selectedProduct, selectedStore)) }
                    }
                }
                .padding(.top, 28)

                if !observations.isEmpty {
                    InfoText(text: "Tap the chart to explore dates and prices.")
                        .padding(.top, 20)
                    if basis == .package {
                        InfoText(text: "Package prices include observations with unknown size. Only known compatible sizes appear in the unit-price chart.")
                            .padding(.top, 8)
                    }
                }
                if let selectedProduct {
                    SecondaryButton(title: "All observations") { router.push(.allHistory(selectedProduct)) }
                    if observations.isEmpty {
                        SecondaryButton(title: "Change scope") { showScope = true }
                    }
                } else {
                    SecondaryButton(title: "Archived products") { router.push(.archivedProducts) }
                }
            }
        }
        .onAppear(perform: resolveSelection)
        .fullScreenCover(isPresented: $showScope) {
            StatisticsScopeView(
                products: products.filter { !$0.isArchived && !$0.observations.isEmpty },
                stores: stores.filter { !$0.isArchived },
                selectedProduct: $selectedProduct,
                selectedStore: $selectedStore
            )
        }
    }

    private func resolveSelection() {
        guard !didResolve else { return }
        didResolve = true
        if selectedProduct == nil {
            selectedProduct = products
                .filter { !$0.isArchived && $0.latestObservation != nil }
                .sorted { lhs, rhs in
                    let left = lhs.latestObservation?.observedAt ?? .distantPast
                    let right = rhs.latestObservation?.observedAt ?? .distantPast
                    return left > right
                }
                .first ?? products.first { !$0.isArchived }
        }
        if selectedStore == nil, let selectedProduct {
            selectedStore = selectedProduct.latestObservation?.store
                ?? selectedProduct.sortedStores.first
        }
    }
}

struct StatisticsScopeView: View {
    let products: [Product]
    let stores: [StoreLocation]
    @Binding var selectedProduct: Product?
    @Binding var selectedStore: StoreLocation?

    @Environment(\.dismiss) private var dismiss
    @State private var localProduct: Product?
    @State private var localStore: StoreLocation?

    private var availableStores: [StoreLocation] {
        guard let localProduct else { return [] }
        return stores.filter { store in
            localProduct.observations.contains { $0.store?.id == store.id }
        }
    }

    var body: some View {
        ScreenScaffold(
            title: "Change scope",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: "Use this scope") {
                    selectedProduct = localProduct
                    selectedStore = localStore
                    dismiss()
                }
                .disabled(localProduct == nil || localStore == nil || !availableStores.contains { $0.id == localStore?.id })
            }
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Product")
                    ForEach(products) { product in
                        SelectionRow(
                            title: product.displayName,
                            subtitle: "\(product.observations.count) observations",
                            isSelected: localProduct?.id == product.id
                        ) {
                            localProduct = product
                            localStore = product.sortedObservations.reversed().compactMap(\.store).first { !$0.isArchived }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Branch")
                    if availableStores.isEmpty {
                        InfoText(text: "This product has no store observations yet.")
                    }
                    ForEach(availableStores) { store in
                        SelectionRow(
                            title: store.displayName,
                            subtitle: store.city,
                            isSelected: localStore?.id == store.id
                        ) {
                            localStore = store
                        }
                    }
                }
            }
            .onAppear {
                localProduct = selectedProduct
                localStore = selectedStore
            }
        }
    }
}
