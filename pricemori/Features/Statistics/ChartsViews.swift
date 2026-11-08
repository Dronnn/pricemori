import SwiftUI
import SwiftData
import Charts

struct StoreSeries: Identifiable {
    let store: StoreLocation
    let observations: [PriceObservation]
    let index: Int

    var id: UUID { store.id }
    var latest: PriceObservation? { observations.last }
}

struct StoreHistoriesView: View {
    let product: Product

    @State private var period: ChartPeriod = .all
    @State private var showPeriod = false

    private var currency: String {
        product.latestRegularObservation?.currencyCode ?? "AMD"
    }

    private var dimension: UnitDimension? {
        PriceMath.dominantDimension(for: product.regularObservations)
    }

    private var series: [StoreSeries] {
        var result: [StoreSeries] = []
        for store in product.sortedStores where !store.isArchived {
            let observations = period.filter(PriceMath.series(
                for: product,
                store: store,
                condition: .regular,
                currency: currency,
                dimension: dimension
            ))
            if !observations.isEmpty {
                result.append(StoreSeries(store: store, observations: observations, index: result.count))
            }
        }
        return result.sorted { lhs, rhs in
            let left = lhs.latest?.observedAt ?? .distantPast
            let right = rhs.latest?.observedAt ?? .distantPast
            return left > right
        }
        .enumerated()
        .map { StoreSeries(store: $0.element.store, observations: $0.element.observations, index: $0.offset) }
    }

    private var primary: StoreSeries? {
        series.max { ($0.observations.count) < ($1.observations.count) }
    }

    private var unitLabel: String {
        series.first?.latest?.baseUnitSymbol ?? "kg"
    }

    private var allDates: [Date] {
        Array(Set(series.flatMap { $0.observations.map(\.observedAt) })).sorted()
    }

    private var grid: [Double] {
        let values = series.flatMap { $0.observations.compactMap { $0.unitPrice.map { NSDecimalNumber(decimal: $0).doubleValue } } }
        return chartGrid(values)
    }

    var body: some View {
        ScreenScaffold(
            title: "Store histories",
            backLabel: "Back",
            trailing: {
                Button("Filter") { showPeriod = true }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.displayName)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Regular observations · \(currency) / \(unitLabel)")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 6)

                if series.isEmpty {
                    InfoText(text: "No comparable observations in this period.")
                        .padding(.top, 28)
                } else {
                    Chart {
                        ForEach(series) { storeSeries in
                            ForEach(storeSeries.observations) { observation in
                                if let unitPrice = observation.unitPrice {
                                    let value = NSDecimalNumber(decimal: unitPrice).doubleValue
                                    if storeSeries.observations.count > 1 {
                                        LineMark(
                                            x: .value("Date", observation.observedAt),
                                            y: .value("Unit price", value)
                                        )
                                        .interpolationMethod(.linear)
                                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                                        .foregroundStyle(Theme.chartLine)
                                    }
                                    if storeSeries.id == primary?.id, observation.id == storeSeries.latest?.id, observation.unitPrice != nil {
                                        PointMark(x: .value("Date", observation.observedAt), y: .value("Unit price", value))
                                            .symbolSize(420)
                                            .foregroundStyle(Theme.chartHalo.opacity(0.13))
                                    }
                                    switch storeSeries.index {
                                    case 0:
                                        PointMark(x: .value("Date", observation.observedAt), y: .value("Unit price", value))
                                            .symbol(.circle)
                                            .symbolSize(observation.id == storeSeries.latest?.id ? 78 : 52)
                                            .foregroundStyle(pointColor(storeSeries, observation))
                                    case 1:
                                        PointMark(x: .value("Date", observation.observedAt), y: .value("Unit price", value))
                                            .symbol(.square)
                                            .symbolSize(60)
                                            .foregroundStyle(pointColor(storeSeries, observation))
                                    default:
                                        PointMark(x: .value("Date", observation.observedAt), y: .value("Unit price", value))
                                            .symbol(.diamond)
                                            .symbolSize(70)
                                            .foregroundStyle(pointColor(storeSeries, observation))
                                    }
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .chartYScale(domain: (grid.first ?? 0)...(grid.last ?? 1))
                    .chartXScale(domain: xDomain)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: grid) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8)).foregroundStyle(Theme.separator)
                            AxisValueLabel {
                                if let raw = value.as(Double.self) {
                                    Text(Format.number(Decimal(raw), maxFraction: 0))
                                        .font(AppFont.inter(13))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: (primary?.observations.map(\.observedAt) ?? allDates)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(Format.shortDate(date))
                                        .font(AppFont.inter(13))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    .frame(height: 230)
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(series) { storeSeries in
                            if let latest = storeSeries.latest, let unitPrice = latest.unitPrice {
                                HStack(spacing: 8) {
                                    Text(symbolGlyph(storeSeries.index))
                                        .font(AppFont.inter(13))
                                        .foregroundStyle(Theme.secondaryText)
                                    Text("\(storeSeries.store.displayName) · \(Format.number(unitPrice, maxFraction: 2)) \(currency) / \(unitLabel) · \(Format.shortDate(latest.observedAt))")
                                        .font(AppFont.inter(13))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    .padding(.top, 22)

                    InfoText(text: comparisonNote)
                        .padding(.top, 30)
                }
            }
        }
        .fullScreenCover(isPresented: $showPeriod) {
            ChartPeriodView(period: $period)
        }
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = allDates.first, let last = allDates.last else {
            return Date.now.addingTimeInterval(-86_400)...Date.now.addingTimeInterval(86_400)
        }
        if first == last {
            return first.addingTimeInterval(-10 * 86_400)...first.addingTimeInterval(10 * 86_400)
        }
        return first.addingTimeInterval(-6 * 86_400)...last.addingTimeInterval(6 * 86_400)
    }

    private func pointColor(_ series: StoreSeries, _ observation: PriceObservation) -> Color {
        if series.id == primary?.id, observation.id == series.latest?.id {
            return Theme.accent
        }
        return Theme.chartLine
    }

    private func symbolGlyph(_ index: Int) -> String {
        switch index {
        case 0: "●"
        case 1: "■"
        default: "◆"
        }
    }

    private var comparisonNote: String {
        guard let primary else { return "" }
        let singles = series.filter { $0.observations.count == 1 }
        let names = singles.map(\.store.name).joined(separator: " and ")
        if singles.isEmpty {
            return "\(primary.store.name) has \(primary.observations.count) observations. Lines connect only recorded points; prices between them are unknown."
        }
        let suffix = singles.count == 1 ? "has one" : "have one each"
        return "\(primary.store.name) has \(primary.observations.count) observations. \(names) \(suffix), so they appear as single points. Lines do not fill the gaps."
    }
}

func chartGrid(_ values: [Double]) -> [Double] {
    guard let minimum = values.min(), let maximum = values.max() else { return [0, 1, 2] }
    if values.count == 1 {
        return [minimum - 20, minimum, minimum + 20]
    }
    if minimum >= 260, maximum <= 340 {
        return [260, 300, 340]
    }
    let span = maximum - minimum
    let step: Double = span <= 80 ? 20 : span <= 200 ? 50 : 100
    let low = floor(minimum / step) * step
    let high = (ceil(maximum / step) + 1) * step
    guard high > low else { return [minimum - step, minimum, minimum + step] }
    return [low, (low + high) / 2, high]
}

struct PeriodChangesView: View {
    var store: StoreLocation?
    var backLabel: String = "Back"

    @EnvironmentObject private var router: AppRouter
    @Query(sort: \Product.createdAt) private var products: [Product]
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var selectedStore: StoreLocation?
    @State private var period: ChartPeriod = .month
    @State private var showFilter = false
    @State private var didResolve = false

    private var activeProducts: [Product] {
        products.filter { !$0.isArchived }
    }

    private var range: ClosedRange<Date> {
        period.range() ?? Date.distantPast...Date.now
    }

    private var currency: String {
        guard let selectedStore else { return "AMD" }
        return activeProducts
            .compactMap { PriceMath.latestObservation(for: $0, store: selectedStore, condition: .regular)?.currencyCode }
            .first ?? "AMD"
    }

    private var rows: [PeriodChangeRow] {
        guard let selectedStore else { return [] }
        return PriceMath.periodChanges(
            products: activeProducts,
            store: selectedStore,
            from: range.lowerBound,
            to: range.upperBound,
            currency: currency
        )
    }

    private var axisMaximum: Decimal {
        let maxPercent = rows.map { abs($0.change.percent) }.max() ?? 15
        let value = NSDecimalNumber(decimal: maxPercent).doubleValue
        let rounded = ceil(value / 5) * 5
        return Decimal(max(15, rounded))
    }

    var body: some View {
        ScreenScaffold(
            title: "Period changes",
            backLabel: backLabel,
            trailing: {
                Button("Filter") { showFilter = true }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(period.displayTitle())
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(selectedStore?.displayName ?? "") · Regular prices")
                    .font(AppFont.inter(15))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 6)

                HStack {
                    Text("−\(Format.number(axisMaximum, maxFraction: 0))%")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("+\(Format.number(axisMaximum, maxFraction: 0))%")
                }
                .font(AppFont.inter(13))
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, 30)

                Rectangle()
                    .fill(Theme.separator)
                    .frame(width: 0.8, height: 14)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(row.product.displayName)
                                    .font(AppFont.inter(16, .medium))
                                    .foregroundStyle(Theme.primaryText)
                                Spacer()
                                Text(Format.percent(row.change.percent))
                                    .font(AppFont.inter(16, .semibold))
                                    .foregroundStyle(Theme.primaryText)
                            }
                            GeometryReader { geometry in
                                let half = geometry.size.width / 2
                                let width = max(4, abs(CGFloat(NSDecimalNumber(decimal: row.change.percent / axisMaximum).doubleValue)) * half)
                                let x = row.change.percent >= 0 ? half : half - width
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Theme.chartLine)
                                    .frame(width: width, height: 10)
                                    .offset(x: x, y: 0)
                            }
                            .frame(height: 10)
                            Text("\(Format.number(row.first.unitPrice ?? 0, maxFraction: 2)) to \(Format.number(row.last.unitPrice ?? 0, maxFraction: 2)) \(row.first.currencyCode) / \(row.first.baseUnitSymbol ?? "") · \(Format.shortDate(row.first.observedAt)) / \(Format.shortDate(row.last.observedAt))")
                                .font(AppFont.inter(13))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.vertical, 18)
                    }
                }
                .overlay {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Theme.separator)
                            .frame(width: 0.8, height: geometry.size.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .allowsHitTesting(false)
                }

                if rows.isEmpty {
                    InfoText(text: "Not enough comparable observations at this branch in the selected period.")
                        .padding(.top, 22)
                }

                InfoText(text: "Each bar compares this product at the same branch and unit. Products with fewer than two comparable observations are excluded.")
                    .padding(.top, 20)
            }
        }
        .onAppear(perform: resolveStore)
        .fullScreenCover(isPresented: $showFilter) {
            PeriodChangesFilterView(
                stores: stores.filter { !$0.isArchived },
                selectedStore: $selectedStore,
                period: $period
            )
        }
    }

    private func resolveStore() {
        guard !didResolve else { return }
        didResolve = true
        selectedStore = store ?? activeProducts
            .compactMap(\.latestRegularObservation?.store)
            .first ?? stores.first { !$0.isArchived }
    }
}

struct PeriodChangesFilterView: View {
    let stores: [StoreLocation]
    @Binding var selectedStore: StoreLocation?
    @Binding var period: ChartPeriod

    @Environment(\.dismiss) private var dismiss
    @State private var localStore: StoreLocation?
    @State private var localPeriod: ChartPeriod = .month

    var body: some View {
        ScreenScaffold(
            title: "Period changes",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: "Apply filters") {
                    selectedStore = localStore
                    period = localPeriod
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Store location")
                    ForEach(stores) { store in
                        SelectionRow(
                            title: store.displayName,
                            subtitle: store.city,
                            isSelected: localStore?.id == store.id
                        ) { localStore = store }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Period")
                    SelectionRow(title: "1 month", isSelected: localPeriod == .month) { localPeriod = .month }
                    SelectionRow(title: "3 months", isSelected: localPeriod == .threeMonths) { localPeriod = .threeMonths }
                    SelectionRow(title: "All time", isSelected: localPeriod == .all) { localPeriod = .all }
                }
            }
            .onAppear {
                localStore = selectedStore
                localPeriod = period
            }
        }
    }
}

struct PackageVsUnitView: View {
    let product: Product
    var store: StoreLocation?

    @State private var period: ChartPeriod = .all
    @State private var showPeriod = false

    private var resolvedStore: StoreLocation? {
        store ?? product.latestRegularObservation?.store
    }

    private var currency: String {
        guard let resolvedStore else { return "AMD" }
        return PriceMath.latestObservation(for: product, store: resolvedStore, condition: .regular)?.currencyCode ?? "AMD"
    }

    private var observations: [PriceObservation] {
        guard let resolvedStore else { return [] }
        return period.filter(PriceMath.series(for: product, store: resolvedStore, condition: .regular, currency: currency))
    }

    private var packageChange: (PriceObservation, PriceObservation)? {
        let sorted = observations.sortedChronologically
        for index in 1..<max(1, sorted.count) {
            let previous = sorted[index - 1]
            let current = sorted[index]
            if previous.packageQuantity != current.packageQuantity,
               previous.packageUnit == current.packageUnit {
                return (previous, current)
            }
        }
        return nil
    }

    private var first: PriceObservation? { observations.first }
    private var last: PriceObservation? { observations.last }

    private var packageChangePercent: Decimal? {
        guard let first, let last, first.id != last.id, first.price != 0 else { return nil }
        return (last.effectivePackagePrice - first.effectivePackagePrice) / first.effectivePackagePrice * 100
    }

    private var unitChangePercent: Decimal? {
        guard let first, let last, first.id != last.id,
              let firstUnit = first.unitPrice, let lastUnit = last.unitPrice, firstUnit != 0
        else { return nil }
        return (lastUnit - firstUnit) / firstUnit * 100
    }

    var body: some View {
        ScreenScaffold(
            title: "Package vs unit",
            backLabel: "Back",
            trailing: {
                Button("Filter") { showPeriod = true }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(resolvedStore.map { "\(product.name) · \($0.name), \($0.branch)" } ?? product.name)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 8)

                if observations.isEmpty {
                    InfoText(text: "No comparable observations for this product at this branch.")
                        .padding(.top, 24)
                } else {
                    FieldLabel(text: "Package price · \(currency)")
                        .padding(.top, 28)
                    PriceChartView(observations: observations, height: 150, showsUnitLabel: true, basis: .package)

                    FieldLabel(text: "Normalized price · \(currency) / \(observations.last?.baseUnitSymbol ?? "kg")")
                        .padding(.top, 28)
                    PriceChartView(observations: observations, height: 150, showsUnitLabel: true, basis: .unit)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Package price: \(packageChangePercent.map { Format.percent($0) } ?? "—")")
                        Text("Unit price: \(unitChangePercent.map { Format.percent($0) } ?? "—")")
                    }
                    .font(AppFont.inter(16, .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.top, 24)

                    InfoText(text: packageChange == nil
                        ? "The package size stayed the same. Unit prices move with the package price."
                        : "The package got smaller. The unit price shows the increase.")
                        .padding(.top, 14)
                }
            }
        }
        .fullScreenCover(isPresented: $showPeriod) {
            ChartPeriodView(period: $period)
        }
    }

    private var subtitle: String {
        if let (previous, current) = packageChange,
           let previousQuantity = previous.packageQuantity,
           let currentQuantity = current.packageQuantity,
           let unit = current.packageUnit {
            return "\(Format.quantity(previousQuantity)) \(unit.symbol) to \(Format.quantity(currentQuantity)) \(unit.symbol) · Same \(Format.money(current.price, currency: current.currencyCode)) \(current.currencyCode) pack price"
        }
        return "Package prices and unit prices across recorded observations"
    }
}

struct MoreComparisonsView: View {
    let product: Product
    @EnvironmentObject private var router: AppRouter

    private var store: StoreLocation? {
        product.latestRegularObservation?.store
    }

    private var currency: String {
        product.latestRegularObservation?.currencyCode ?? "AMD"
    }

    private var observations: [PriceObservation] {
        guard let store else { return [] }
        return PriceMath.series(for: product, store: store, condition: .regular, currency: currency)
    }

    private var range: RecordedRange? {
        PriceMath.allTimeRange(for: observations)
    }

    var body: some View {
        ScreenScaffold(
            title: "More comparisons",
            backLabel: "Charts",
            footer: {
                SecondaryButton(title: "Compare latest store prices") {
                    router.push(.compareStores(product))
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text("How do stores differ\nover time?")
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)

                OpenRow(title: "Compare branch histories", subtitle: "How do stores differ over time?") {
                    router.push(.storeHistories(product))
                }
                SeparatorLine()
                OpenRow(title: "Did the package get smaller?", subtitle: "Compare package price and price per kg") {
                    router.push(.packageVsUnit(product, store))
                }
                SeparatorLine()

                FieldLabel(text: "Your recorded range\(store.map { " · \($0.name)" } ?? "")")
                    .padding(.top, 24)

                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.top, 10)
                Text("Regular · All time · \(currency) / \(observations.last?.baseUnitSymbol ?? "kg")")
                    .font(AppFont.inter(16))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.top, 2)

                if let range {
                    RangeBar(
                        minimum: range.minimum.unitPrice ?? 0,
                        maximum: range.maximum.unitPrice ?? 0,
                        latest: range.latest.unitPrice ?? 0
                    )
                    .padding(.top, 30)

                    HStack {
                        Text(Format.number(range.minimum.unitPrice ?? 0, maxFraction: 2))
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Text("\(Format.number(range.latest.unitPrice ?? 0, maxFraction: 2)) latest")
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                    }
                    .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum \(Format.number(range.minimum.unitPrice ?? 0, maxFraction: 2)) · \(Format.shortDate(range.minimum.observedAt))")
                        Text("Maximum \(range.maximum.unitPrice == range.latest.unitPrice ? "and latest " : "")\(Format.number(range.maximum.unitPrice ?? 0, maxFraction: 2)) · \(Format.shortDate(range.maximum.observedAt))")
                    }
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 16)
                } else {
                    InfoText(text: "No recorded range yet.")
                        .padding(.top, 20)
                }

                InfoText(text: "Your lowest recorded price is different from another store’s last known price.")
                    .padding(.top, 26)
            }
        }
    }
}

struct RangeBar: View {
    let minimum: Decimal
    let maximum: Decimal
    let latest: Decimal

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.separator)
                    .frame(height: 1)
                    .offset(y: -0.5)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 20)
                    .offset(x: 0, y: -10)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 20)
                    .offset(x: geometry.size.width - 4, y: -10)
            }
        }
        .frame(height: 20)
    }
}

struct ChartPeriodView: View {
    @Binding var period: ChartPeriod
    @Environment(\.dismiss) private var dismiss

    @State private var selected: ChartPeriod = .month
    @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var to = Date.now

    private var isCustom: Bool {
        if case .custom = selected { return true }
        return false
    }

    var body: some View {
        ScreenScaffold(
            title: "Chart period",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: "Use this period") {
                    if isCustom {
                        period = .custom(from: from, to: to)
                    } else {
                        period = selected
                    }
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 8) {
                    FilterChip(title: "1 month", isSelected: selected == .month) { selected = .month }
                    FilterChip(title: "3 months", isSelected: selected == .threeMonths) { selected = .threeMonths }
                    FilterChip(title: "All time", isSelected: selected == .all) { selected = .all }
                }

                VStack(alignment: .leading, spacing: 12) {
                    FieldLabel(text: "Custom range")
                    HStack {
                        Text("From")
                            .font(AppFont.inter(15))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        DatePicker("", selection: $from, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .environment(\.locale, Locale(identifier: "en_GB"))
                    }
                    HStack {
                        Text("Through")
                            .font(AppFont.inter(15))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        DatePicker("", selection: $to, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .environment(\.locale, Locale(identifier: "en_GB"))
                    }
                }

                FilterChip(title: "Custom", isSelected: isCustom) { selected = .custom(from: from, to: to) }

                InfoText(text: "Only recorded observations inside the range are plotted. No daily values are generated.")
            }
            .onAppear {
                selected = period
                if case .custom(let customFrom, let customTo) = period {
                    from = customFrom
                    to = customTo
                }
            }
        }
    }
}

struct ChartFiltersView: View {
    let product: Product
    let stores: [StoreLocation]
    @Binding var store: StoreLocation
    @Binding var period: ChartPeriod
    @Binding var basis: ChartBasis
    @Binding var condition: ObservationCondition

    @Environment(\.dismiss) private var dismiss
    @State private var localStore: StoreLocation
    @State private var localPeriod: ChartPeriod
    @State private var localBasis: ChartBasis
    @State private var localCondition: ObservationCondition
    @State private var showPeriod = false

    init(
        product: Product,
        stores: [StoreLocation],
        store: Binding<StoreLocation>,
        period: Binding<ChartPeriod>,
        basis: Binding<ChartBasis>,
        condition: Binding<ObservationCondition>
    ) {
        self.product = product
        self.stores = stores
        _store = store
        _period = period
        _basis = basis
        _condition = condition
        _localStore = State(initialValue: store.wrappedValue)
        _localPeriod = State(initialValue: period.wrappedValue)
        _localBasis = State(initialValue: basis.wrappedValue)
        _localCondition = State(initialValue: condition.wrappedValue)
    }

    var body: some View {
        ScreenScaffold(
            title: "Chart filters",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                VStack(spacing: 0) {
                    PrimaryButton(title: "Apply filters") {
                        store = localStore
                        period = localPeriod
                        basis = localBasis
                        condition = localCondition
                        dismiss()
                    }
                    SecondaryButton(title: "Reset choices") {
                        localPeriod = .month
                        localBasis = .unit
                        localCondition = .regular
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Product")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    Text(product.displayName)
                        .font(AppFont.inter(16))
                        .foregroundStyle(Theme.primaryText)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 48)
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Branch scope")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    Menu {
                        ForEach(stores) { item in
                            Button(item.displayName) { localStore = item }
                        }
                    } label: {
                        HStack {
                            Text(localStore.displayName)
                                .font(AppFont.inter(16))
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Period")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    Button {
                        showPeriod = true
                    } label: {
                        HStack {
                            Text(localPeriod.displayTitle())
                                .font(AppFont.inter(16))
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Price basis")
                    HStack(spacing: 8) {
                        ForEach(ChartBasis.allCases) { option in
                            FilterChip(title: option.title, isSelected: localBasis == option) {
                                localBasis = option
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Offers")
                    HStack(spacing: 8) {
                        FilterChip(title: "Regular", isSelected: localCondition == .regular) { localCondition = .regular }
                        FilterChip(title: "Card", isSelected: localCondition == .card) { localCondition = .card }
                        FilterChip(title: "Multi-buy", isSelected: localCondition == .multiBuy) { localCondition = .multiBuy }
                    }
                }

                InfoText(text: "Currency: \(product.latestRegularObservation?.currencyCode ?? "AMD") · Include archived: Off\nDifferent currencies are kept separate.")
            }
            .fullScreenCover(isPresented: $showPeriod) {
                ChartPeriodView(period: $localPeriod)
            }
        }
    }
}
