import SwiftUI
import SwiftData

struct PriceOverTimeView: View {
    let product: Product
    var initialStore: StoreLocation?
    var backLabel: String = "Back"
    var initialCondition: ObservationCondition = .regular
    var initialReferenceID: UUID? = nil

    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var selectedStore: StoreLocation?
    @State private var period: ChartPeriod = .all
    @State private var basis: ChartBasis = .unit
    @State private var condition: ObservationCondition = .regular
    @State private var showFilters = false
    @State private var showCustomPeriod = false
    @State private var showRecord = false
    @State private var selectedDate: Date?
    @State private var didResolve = false
    @State private var selectedCurrency: String?
    @State private var selectedOfferID: UUID?
    @State private var deletedSnapshot: ObservationSnapshot?
    @State private var deletedStore: StoreLocation?
    @State private var deletionMessage: String?
    @State private var saveError = false
    @State private var savedObservationID: UUID?

    private var savedObservation: PriceObservation? { product.observations.first { $0.id == savedObservationID } }

    private var activeStores: [StoreLocation] {
        stores.filter { !$0.isArchived }
    }

    private var scopeReference: PriceObservation? {
        let candidates = product.observations.filter {
            $0.store?.id == selectedStore?.id && $0.condition == condition
                && (selectedCurrency == nil || $0.currencyCode == selectedCurrency)
        }.sortedChronologically
        return candidates.first { $0.id == selectedOfferID } ?? candidates.last
    }

    private var scopedObservations: [PriceObservation] {
        guard let selectedStore else { return [] }
        return PriceMath.series(
            for: product, store: selectedStore, condition: condition,
            currency: selectedCurrency ?? scopeReference?.currencyCode,
            reference: scopeReference, includeUnknownSize: basis == .package
        )
    }

    private var filteredObservations: [PriceObservation] { period.filter(scopedObservations) }
    private var current: PriceObservation? { filteredObservations.last }
    private var unitLabel: String {
        basis == .package ? "package" : scopedObservations.last?.baseUnitSymbol ?? "unit"
    }
    private var range: ClosedRange<Decimal>? { ChartValues.range(filteredObservations, basis: basis) }
    private var selectedChange: Decimal? { ChartValues.percentChange(filteredObservations, basis: basis) }

    var body: some View {
        ScreenScaffold(
            saveError: $saveError,
            title: filteredObservations.count < 2 ? "More data needed" : "Price over time",
            backLabel: backLabel,
            trailing: {
                HeaderActionButton(title: "Filter") { showFilters = true }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                Text("\(selectedStore?.displayName ?? "") · \(scopeReference?.conditionLine ?? condition.shortTitle) · \(selectedCurrency ?? scopeReference?.currencyCode ?? "") / \(unitLabel)")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 4)

                if let deletionMessage {
                    SavedBanner(text: deletionMessage, undo: undoDeletion).padding(.top, 14)
                }
                if let savedObservation {
                    SavedBanner(text: "Price saved") {
                        context.delete(savedObservation)
                        if context.saveReportingError(&saveError) { savedObservationID = nil }
                    }.padding(.top, 14)
                }

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

                    if let selectedChange, let first = filteredObservations.first {
                        Text("\(Format.percent(selectedChange)) since \(Format.shortDate(first.observedAt))")
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

                if filteredObservations.count < 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Not enough comparable prices")
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Text(product.displayName)
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)

                        if let only = filteredObservations.first {
                            PriceChartView(observations: [only], height: 180, showsUnitLabel: true, basis: basis)
                            Text("One observation matches these filters\n\(ChartValues.amount(only, basis: basis).map { Format.number($0, maxFraction: 2) } ?? "—") \(only.currencyCode) / \(unitLabel) · \(Format.timestamp(only.observedAt))")
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                                .lineSpacing(3)
                        } else {
                            Text("No recorded observations match these filters")
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                        }

                        if basis == .unit, let selectedStore,
                           !period.filter(PriceMath.series(for: product, store: selectedStore, condition: condition,
                               currency: selectedCurrency ?? scopeReference?.currencyCode,
                               reference: scopeReference, includeUnknownSize: true)).isEmpty {
                            SecondaryButton(title: "View package prices") { basis = .package }
                        }

                        InfoText(text: "A price change needs two observations with the same branch, currency, units and conditions.")
                            .padding(.top, 4)

                        if !product.isArchived {
                            PrimaryButton(title: "Record another observation") { showRecord = true }
                        }
                        SecondaryButton(title: "Change chart filters") { showFilters = true }

                        InfoText(text: "One price is still useful. Keep it visible in history without inventing a trend.")
                            .padding(.top, 10)
                    }
                    .padding(.top, 18)
                } else {
                    PriceChartView(
                        observations: filteredObservations,
                        height: 220,
                        showsUnitLabel: true,
                        basis: basis,
                        selectedDate: $selectedDate
                    )
                    .padding(.top, 18)

                    if let selectedObservation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(Format.timestamp(selectedObservation.observedAt)) · \(ChartValues.amount(selectedObservation, basis: basis).map { Format.number($0, maxFraction: 2) } ?? "—") \(selectedObservation.currencyCode) / \(unitLabel)")
                                .font(AppFont.inter(16, .semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("\(selectedObservation.packagePriceLine) · \(selectedObservation.store?.displayName ?? "")")
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                            NavigationLink {
                                ObservationDetailView(product: product, observation: selectedObservation, backLabel: "Chart", onDelete: { [store = selectedObservation.store] snapshot in
                                    deletedSnapshot = snapshot
                                    deletedStore = store
                                    deletionMessage = "Observation removed"
                                    selectedDate = nil
                                })
                            } label: {
                                Text("Open this observation")
                                    .font(AppFont.inter(15, .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 10)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let first = filteredObservations.first, let last = filteredObservations.last, let range {
                            if let selectedChange {
                                Text("\(Format.number(range.lowerBound, maxFraction: 2)) to \(Format.number(range.upperBound, maxFraction: 2)) \(current?.currencyCode ?? "AMD") / \(unitLabel) · \(Format.percent(selectedChange))")
                            }
                            Text("Selected period: \(Format.periodRange(from: first.observedAt, to: last.observedAt))\n\(filteredObservations.count) observations")
                        }
                    }
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .padding(.top, 14)
                }

                SecondaryButton(title: "View observation list") {
                    guard let selectedStore else { return }
                    if let scopeReference {
                        router.push(.scopedHistory(product, selectedStore, condition, scopeReference.currencyCode, scopeReference.id))
                    } else {
                        router.push(.history(product, selectedStore, condition))
                    }
                }
                .padding(.top, 18)
                .disabled(selectedStore == nil)

                SecondaryButton(title: "All observations") { router.push(.allHistory(product)) }

                InfoText(text: "Lines connect recorded points; prices between them are unknown.")
                    .padding(.top, 18)
            }
        }
        .onAppear(perform: resolveStore)
        .onChange(of: filteredObservations.map(\.id)) { selectedDate = nil }
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
                    condition: $condition,
                    currency: $selectedCurrency,
                    offerID: $selectedOfferID
                )
            }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordPriceView(product: product, initialStore: selectedStore, initialObservation: scopeReference) { observation in
                selectedStore = observation.store
                selectedCurrency = observation.currencyCode
                selectedOfferID = observation.id
                condition = observation.condition
                basis = .preferred(for: observation)
                period = .all
                selectedDate = observation.observedAt
                savedObservationID = observation.id
            }
        }
    }

    private func undoDeletion() {
        guard let deletedSnapshot, let deletedStore else { return }
        let observation = deletedSnapshot.makeObservation(product: product, store: deletedStore)
        context.insert(observation)
        guard context.saveReportingError(&saveError) else { return }
        self.deletedSnapshot = nil
        self.deletedStore = nil
        deletionMessage = nil
    }

    private var selectedObservation: PriceObservation? {
        guard let selectedDate else { return nil }
        return filteredObservations.min {
            abs($0.observedAt.timeIntervalSince(selectedDate)) < abs($1.observedAt.timeIntervalSince(selectedDate))
        }
    }

    private var isCustomPeriod: Bool {
        if case .custom = period { return true }
        return false
    }

    private func resolveStore() {
        guard !didResolve else { return }
        didResolve = true
        condition = initialCondition
        selectedOfferID = initialReferenceID
        selectedCurrency = product.observations.first { $0.id == initialReferenceID }?.currencyCode
        selectedStore = initialStore ?? product.latestObservation?.store ?? activeStores.first
        basis = .preferred(for: scopeReference)
    }
}
