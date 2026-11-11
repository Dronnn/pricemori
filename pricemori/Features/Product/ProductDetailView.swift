import SwiftUI
import SwiftData

struct ProductDetailView: View {
    let product: Product
    var backLabel: String = "Journal"
    var isFirstSave: Bool = false
    var initialStore: StoreLocation?

    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var leaveAfterEdit = false
    @State private var showRecord = false
    @State private var savedMessage: String?
    @State private var savedObservationID: UUID?
    @State private var focusedObservationID: UUID?
    @State private var confirmConditionalRepeat = false
    @State private var removal: ObservationRemoval?

    init(product: Product, backLabel: String = "Journal", isFirstSave: Bool = false, initialStore: StoreLocation? = nil, savedObservation: PriceObservation? = nil) {
        self.product = product
        self.backLabel = backLabel
        self.isFirstSave = isFirstSave
        self.initialStore = initialStore
        _savedObservationID = State(initialValue: savedObservation?.id ?? (isFirstSave ? product.latestObservation?.id : nil))
        _focusedObservationID = State(initialValue: savedObservation?.id)
        _savedMessage = State(initialValue: savedObservation != nil ? "Price saved" : isFirstSave ? "First price saved" : nil)
    }

    private var savedObservation: PriceObservation? { product.observations.first { $0.id == savedObservationID } }
    private var focusedObservation: PriceObservation? { product.observations.first { $0.id == focusedObservationID } }

    private var primary: PriceObservation? {
        let store = focusedObservation?.store ?? initialStore
        let candidates = product.observations.filter { observation in
            (store == nil || observation.store?.id == store?.id)
                && (focusedObservation.map { PriceMath.sameOffer($0, observation) && $0.currencyCode == observation.currencyCode } ?? true)
        }
        return candidates.max { PriceMath.isEarlier($0, than: $1) }
    }

    private var primaryStore: StoreLocation? {
        primary?.store
    }

    private var currency: String {
        primary?.currencyCode ?? "AMD"
    }

    private var chartBasis: ChartBasis { .preferred(for: primary) }

    private var series: [PriceObservation] {
        guard let primaryStore else { return [] }
        return PriceMath.series(
            for: product,
            store: primaryStore,
            condition: primary?.condition ?? .regular,
            currency: currency,
            reference: primary,
            includeUnknownSize: chartBasis == .package
        )
    }

    private var change: PriceChange? {
        guard let primary else { return nil }
        return PriceMath.change(for: primary, among: product.observations)
    }

    private var otherStores: [StorePrice] {
        guard let primaryStore, let primary else { return [] }
        return PriceMath.latestPerStore(for: product, condition: primary.condition, currency: currency)
            .filter { $0.store.id != primaryStore.id && !$0.store.isArchived && PriceMath.comparable($0.observation, primary) }
            .sorted { ($0.unitPrice ?? 0) < ($1.unitPrice ?? 0) }
    }

    private var conditionalObservations: [PriceObservation] {
        Array(product.observations
            .filter { $0.condition != .regular }
            .sortedChronologically
            .reversed())
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            backLabel: backLabel,
            topPadding: 16,
            trailing: {
                HeaderActionButton(title: "Edit") { showEdit = true }
            },
            footer: {
                if product.isArchived {
                    PrimaryButton(title: "Restore product") {
                        product.isArchived = false
                        product.archivedAt = nil
                        _ = context.saveReportingError(&saveError)
                    }
                } else if series.count <= 1, primary != nil {
                    PrimaryButton(title: isFirstSave ? "Back to Journal" : "Record a price") {
                        if isFirstSave {
                            dismiss()
                        } else {
                            showRecord = true
                        }
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.name)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(AppFont.inter(15))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 4)
                }

                if removal != nil {
                    SavedBanner(text: "Observation removed") {
                        removal?.restore(product: product, context: context)
                        if context.saveReportingError(&saveError) { removal = nil }
                    }.padding(.top, 14)
                }

                if let savedMessage, savedObservation != nil {
                    SavedBanner(text: savedMessage, undo: undoLast)
                        .padding(.top, 14)
                }

                if product.isArchived {
                    InfoText(text: "Restored products return to the Journal with all their earlier prices.")
                        .padding(.top, 12)
                }

                if !product.observations.isEmpty {
                    OpenRow(title: "All observations", subtitle: L10n.format("%lld recorded prices", product.observations.count)) {
                        router.push(.allHistory(product))
                    }
                    .accessibilityIdentifier("all-product-observations")
                    .padding(.top, 12)
                }

                if let primary, let store = primary.store {
                    Text(store.displayName)
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                        .padding(.top, savedMessage == nil ? 14 : 18)

                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(Format.number(primary.headlineAmount, maxFraction: 2))
                            .font(AppFont.serif(50))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(primary.headlineUnit)
                            .font(AppFont.inter(18))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(primary.packageSummary) · \(primary.conditionLine)")
                        Text(Format.dateAndAge(primary.observedAt))
                        Text("\(primary.condition == .regular ? L10n.string("Regular price") : primary.conditionLine) · \(primary.source.title)")
                    }
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 4)

                    if let change {
                        HStack(alignment: .firstTextBaseline) {
                            Text(change.summary)
                                .font(AppFont.inter(16, .semibold))
                                .foregroundStyle(Theme.primaryText)
                            Spacer(minLength: 8)
                            Text("since \(Format.shortDate(change.previous.observedAt))")
                                .font(AppFont.inter(13))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.top, 12)
                    }

                    if !product.isArchived, series.count > 1 {
                        PrimaryButton(title: "Record a price") { showRecord = true }
                            .padding(.top, 18)
                        SecondaryButton(title: "No change · record today", action: repeatTapped)
                    } else if !product.isArchived {
                        SecondaryButton(title: "No change · record today", action: repeatTapped)
                            .padding(.top, 12)
                    }

                    SectionTitle(text: "Price history", actionTitle: "History") {
                        router.push(.scopedHistory(product, store, primary.condition, primary.currencyCode, primary.id))
                    }
                    .padding(.top, 26)

                    NavigationLink(value: AppRoute.scopedPriceOverTime(product, store, primary.id)) {
                        PriceChartView(observations: series, basis: chartBasis)
                            .padding(.top, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Text(series.count == 1
                        ? "1 observation · No estimates between dates"
                        : "\(series.count) observations · No estimates between dates")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 8)

                    if chartBasis == .package {
                        InfoText(text: "Package prices include observations with unknown size. Only known compatible sizes appear in the unit-price chart.")
                            .padding(.top, 6)
                    }

                    ForEach(Array(product.sortedObservations.suffix(3).reversed())) { observation in
                        let observationStore = observation.store
                        NavigationLink {
                            ObservationDetailView(product: product, observation: observation, backLabel: "Product", onDelete: { snapshot in
                                if let observationStore { removal = ObservationRemoval(snapshot: snapshot, store: observationStore) }
                            })
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(observation.packagePriceLine).font(AppFont.inter(15, .medium))
                                    Text("\(Format.timestamp(observation.observedAt)) · \(observation.store?.displayName ?? "")")
                                        .font(AppFont.inter(13)).foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            .foregroundStyle(Theme.primaryText)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        SeparatorLine()
                    }

                    if !otherStores.isEmpty {
                        SectionTitle(text: "Other stores · last known", actionTitle: "Compare stores") {
                            router.push(.compareStores(product))
                        }
                        .padding(.top, 26)

                        VStack(spacing: 0) {
                            ForEach(otherStores, id: \.store.id) { item in
                                OtherStoreRow(item: item)
                                if item.store.id != otherStores.last?.store.id {
                                    SeparatorLine()
                                }
                            }
                        }

                        InfoText(text: L10n.format("%@ · %@ · Prices may have changed", currency, primary.conditionLine))
                            .padding(.top, 6)
                    }

                    if !conditionalObservations.isEmpty {
                        OpenRow(
                            title: "Conditional offers",
                            subtitle: "Card and multi-buy prices are kept in their own comparison",
                            value: nil
                        ) {
                            router.push(.conditionalOffers(product))
                        }
                        .padding(.top, 18)
                    }

                    VStack(spacing: 2) {
                        SecondaryButton(title: "Compare stores") {
                            router.push(.compareStores(product))
                        }
                        SecondaryButton(title: "Statistics") {
                            router.push(.statistics(product, store))
                        }
                    }
                    .padding(.top, 16)
                } else {
                    if !product.observations.isEmpty {
                        InfoText(text: "No observations match this scope. Your saved prices are available in All observations.")
                            .padding(.top, 24)
                        SecondaryButton(title: "Statistics") { router.push(.statistics(product, nil)) }
                        if !product.isArchived {
                            PrimaryButton(title: "Record a price") { showRecord = true }
                        }
                    } else if !product.isArchived {
                        PriceEmptyState { showRecord = true }
                            .padding(.top, 24)
                    }

                    if !conditionalObservations.isEmpty {
                        OpenRow(
                            title: "Conditional offers",
                            subtitle: "Card and multi-buy prices are kept in their own comparison"
                        ) {
                            router.push(.conditionalOffers(product))
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .alert("Confirm offer conditions", isPresented: $confirmConditionalRepeat) {
            Button("Cancel", role: .cancel) {}
            Button("Record today") { recordNoChange() }
        } message: {
            Text("Confirm that the same eligibility and minimum quantity apply today. For a different offer, record a new price.")
        }
        .fullScreenCover(isPresented: $showEdit, onDismiss: {
            if leaveAfterEdit {
                leaveAfterEdit = false
                router.reset()
            }
        }) {
            NavigationStack {
                ProductEditView(product: product) {
                    leaveAfterEdit = true
                    showEdit = false
                }
            }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordPriceView(product: product, initialStore: (primaryStore ?? initialStore).flatMap { $0.isArchived ? nil : $0 }, initialObservation: primary) { observation in
                savedObservationID = observation.id
                focusedObservationID = observation.id
                savedMessage = saveFeedback(for: observation)
            }
        }
    }

    private func saveFeedback(for observation: PriceObservation) -> String {
        guard observation.sizeKnown else {
            return L10n.string("Price saved · Package size unknown")
        }
        if let previous = PriceMath.previousComparable(for: observation, among: product.observations),
           previous.packageQuantity != observation.packageQuantity
            || previous.packageUnit != observation.packageUnit {
            let old = [previous.packageQuantity.map { NSDecimalNumber(decimal: $0).stringValue }, previous.packageUnit?.symbol]
                .compactMap { $0 }.joined(separator: " ")
            let new = [observation.packageQuantity.map { NSDecimalNumber(decimal: $0).stringValue }, observation.packageUnit?.symbol]
                .compactMap { $0 }.joined(separator: " ")
            return L10n.format("Size change saved · %@ to %@", old, new)
        }
        return L10n.format("Price saved · %@", Format.relativeAge(observation.observedAt))
    }

    private func repeatTapped() {
        guard let primary, primary.store?.isArchived == false else { showRecord = true; return }
        if primary.condition != .regular {
            if primary.isExpired { showRecord = true } else { confirmConditionalRepeat = true }
        } else {
            recordNoChange()
        }
    }

    private func recordNoChange() {
        guard let primary, let store = primary.store, !store.isArchived else { return }
        let observation = PriceObservation(
            price: primary.price,
            currencyCode: primary.currencyCode,
            observedAt: .now,
            packageQuantity: primary.packageQuantity,
            packageUnit: primary.packageUnit,
            sizeKnown: primary.sizeKnown,
            isLoose: primary.isLoose,
            condition: primary.condition,
            conditionLabel: primary.conditionLabel,
            conditionEndDate: primary.conditionEndDate,
            multiBuyMinimum: primary.multiBuyMinimum,
            source: primary.source,
            note: primary.note,
            product: product,
            store: store
        )
        context.insert(observation)
        guard context.saveReportingError(&saveError) else { return }
        savedObservationID = observation.id
        savedMessage = "Recorded today · No change"
    }

    private func undoLast() {
        guard let savedObservation else { return }
        context.delete(savedObservation)
        guard context.saveReportingError(&saveError) else { return }
        self.savedObservationID = nil
        focusedObservationID = nil
        savedMessage = nil
    }
}

struct OtherStoreRow: View {
    let item: StorePrice

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.store.displayName)
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)
                Text("\(Format.dateAndAge(item.observation.observedAt))\(item.observation.isExpired ? " · " + L10n.string("Expired offer") : "")")
                    .font(AppFont.inter(13))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.observation.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.money(item.observation.price, currency: item.observation.currencyCode))
                    .font(AppFont.inter(19, .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(item.observation.unitPrice != nil
                    ? "\(item.observation.currencyCode) / \(item.observation.baseUnitSymbol ?? "")"
                    : "\(item.observation.currencyCode) / package")
                    .font(AppFont.inter(12))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 12)
    }
}

struct PriceEmptyState: View {
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoText(text: "Start this product’s history")
            InfoText(text: "Record a price at any store. You can add a shelf price without buying the product.")
            PrimaryButton(title: "Record first price", action: onRecord)
            InfoText(text: "Charts and price changes will appear when there is enough comparable data.")
                .padding(.top, 12)
        }
    }
}

struct ProductEditView: View {
    let product: Product
    let onArchive: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveError = false

    @State private var name = ""
    @State private var brand = ""
    @State private var variety = ""
    @State private var isFavorite = false
    @State private var showArchiveAlert = false
    @State private var showDeleteAlert = false
    @State private var confirmDiscard = false
    @State private var showValidation = false

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Edit product",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: {
                if hasChanges { confirmDiscard = true } else { dismiss() }
            },
            footer: {
                PrimaryButton(title: "Save product") { save() }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Product name *")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Buckwheat", text: $name)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brand or model")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Brand X", text: $brand)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variety / identifying detail")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Whole grain", text: $variety)
                }
                Toggle(isOn: $isFavorite) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Favorite · \(isFavorite ? "On" : "Off")")
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Text("Show this product in Favorites")
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .tint(Theme.accent)

                if showValidation {
                    Text("Enter a product name.")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }

                InfoText(text: "Correct labels here. A different brand or variety needs a separate product. Saved package sizes stay unchanged.")

                SecondaryButton(title: product.isArchived ? "Restore product" : "Archive product…") {
                    if product.isArchived {
                        product.isArchived = false
                        product.archivedAt = nil
                        guard context.saveReportingError(&saveError) else { return }
                        dismiss()
                    } else {
                        showArchiveAlert = true
                    }
                }
                .padding(.top, 12)
                .alert("Stop tracking this product?", isPresented: $showArchiveAlert) {
                    Button("Keep tracking", role: .cancel) {}
                    Button("Archive", role: .destructive) {
                        product.isArchived = true
                        product.archivedAt = .now
                        guard context.saveReportingError(&saveError) else { return }
                        onArchive()
                    }
                } message: {
                    Text(L10n.string("It will leave the active Journal and entry pickers. Its history, statistics and backup data will be kept.") + "\n" + L10n.string("Its history is kept. Restore it from Archived products."))
                }
                SecondaryButton(title: "Delete product…", color: Theme.error) { showDeleteAlert = true }
                    .alert("Delete product permanently?", isPresented: $showDeleteAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete product", role: .destructive) {
                            context.delete(product)
                            guard context.saveReportingError(&saveError) else { return }
                            onArchive()
                        }
                    } message: {
                        Text(L10n.format("Delete %@ and all %lld recorded prices? This cannot be undone.", product.name, product.observations.count) + "\n" + L10n.string("Archive it instead to keep its history."))
                    }
            }
            .alert("Discard changes?", isPresented: $confirmDiscard) {
                Button("Keep editing", role: .cancel) {}
                Button("Discard draft", role: .destructive) { dismiss() }
            }
            .onAppear {
                name = product.name
                brand = product.brand
                variety = product.variety
                isFavorite = product.isFavorite
            }
        }
    }

    private var hasChanges: Bool {
        name != product.name || brand != product.brand || variety != product.variety || isFavorite != product.isFavorite
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showValidation = true
            return
        }
        product.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        product.brand = brand.trimmingCharacters(in: .whitespaces)
        product.variety = variety.trimmingCharacters(in: .whitespaces)
        product.isFavorite = isFavorite
        guard context.saveReportingError(&saveError) else { return }
        dismiss()
    }
}

struct ConditionalOffersView: View {
    let product: Product

    @EnvironmentObject private var router: AppRouter
    @State private var selectedOffer: PriceObservation?

    private var activeOffers: [PriceObservation] {
        Array(product.observations
            .filter { $0.condition != .regular && !$0.isExpired }
            .sortedChronologically
            .reversed())
    }

    private var expiredOffers: [PriceObservation] {
        Array(product.observations
            .filter { $0.condition != .regular && $0.isExpired }
            .sortedChronologically
            .reversed())
    }

    var body: some View {
        ScreenScaffold(title: "Conditional offers", backLabel: "Product") {
            VStack(alignment: .leading, spacing: 16) {
                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)

                InfoText(text: "Offers are separated by eligibility and minimum quantity. Regular prices stay in their own comparison.")

                if activeOffers.isEmpty && expiredOffers.isEmpty {
                    InfoText(text: "No card or multi-buy offers are recorded for this product.")
                }

                LazyVStack(spacing: 0) {
                    ForEach(activeOffers) { offer in
                        Button {
                            selectedOffer = offer
                        } label: {
                            OfferRow(observation: offer)
                        }
                        .buttonStyle(.plain)
                        SeparatorLine()
                    }
                }

                if !expiredOffers.isEmpty {
                    SectionTitle(text: "Expired offers")
                        .padding(.top, 8)
                    LazyVStack(spacing: 0) {
                        ForEach(expiredOffers) { offer in
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

                InfoText(text: "Expired offers stay in history with their end date. They are not treated as available now.")

                SecondaryButton(title: "Compare regular prices") {
                    router.push(.compareStores(product))
                }
                .padding(.top, 8)
            }
        }
        .fullScreenCover(item: $selectedOffer) { offer in
            OfferDetailView(product: product, observation: offer)
        }
    }
}

struct OfferRow: View {
    let observation: PriceObservation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(observation.store?.displayName ?? "") · \(observation.condition == .card ? "Card offer" : "Multi-buy")")
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                Text(observation.condition == .multiBuy
                    ? observation.multiBuySummary
                    : "\(observation.unitPriceLine ?? observation.packagePriceLine) · \(observation.conditionLabel)")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                Text("\(Format.dateAndAge(observation.observedAt)) · \(observation.packageSummary)")
                    .font(AppFont.inter(13))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            Text(observation.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.money(observation.price, currency: observation.currencyCode))
                .font(AppFont.inter(19, .semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct OfferDetailView: View {
    let product: Product
    let observation: PriceObservation
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ScreenScaffold(
            title: observation.condition == .card ? "Card-price detail" : "Multi-buy detail",
            backLabel: "Offers",
            backAction: { dismiss() },
            footer: {
                VStack(spacing: 0) {
                    PrimaryButton(title: "Compare conditional offers") { dismiss() }
                    SecondaryButton(title: "View regular store prices") {
                        dismiss()
                        router.push(.compareStores(product))
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(observation.unitPrice.map { "\(Format.number($0, maxFraction: 2)) \(observation.currencyCode) / \(observation.baseUnitSymbol ?? "")" } ?? observation.packagePriceLine)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                Text(observation.conditionLine)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                Text(observation.store?.displayName ?? "")
                    .font(AppFont.inter(15))
                    .foregroundStyle(Theme.secondaryText)
                Text("\(observation.packagePriceLine) · \(observation.source.title)\n\(Format.dateAndAge(observation.observedAt))")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)

                InfoText(text: "Regular and conditional prices have different eligibility, so no like-for-like change is calculated between them.")

                if let endDate = observation.conditionEndDate {
                    InfoText(text: "Offer ends \(Format.date(endDate)).")
                }
            }
        }
    }
}
