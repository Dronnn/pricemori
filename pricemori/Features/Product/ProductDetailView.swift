import SwiftUI
import SwiftData

struct ProductDetailView: View {
    let product: Product
    var backLabel: String = "Journal"
    var isFirstSave: Bool = false

    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showRecord = false
    @State private var savedMessage: String?
    @State private var savedObservation: PriceObservation?

    init(product: Product, backLabel: String = "Journal", isFirstSave: Bool = false) {
        self.product = product
        self.backLabel = backLabel
        self.isFirstSave = isFirstSave
        _savedMessage = State(initialValue: isFirstSave ? "First price saved" : nil)
    }

    private var primary: PriceObservation? {
        product.latestRegularObservation
    }

    private var primaryStore: StoreLocation? {
        primary?.store
    }

    private var currency: String {
        primary?.currencyCode ?? "AMD"
    }

    private var series: [PriceObservation] {
        guard let primaryStore else { return [] }
        return PriceMath.series(
            for: product,
            store: primaryStore,
            condition: .regular,
            currency: currency
        )
    }

    private var change: PriceChange? {
        guard let primary else { return nil }
        return PriceMath.change(for: primary, among: product.observations)
    }

    private var otherStores: [StorePrice] {
        guard let primaryStore else { return [] }
        return PriceMath.latestPerStore(for: product, condition: .regular, currency: currency)
            .filter { $0.store.id != primaryStore.id && !$0.store.isArchived }
            .sorted { ($0.unitPrice ?? 0) < ($1.unitPrice ?? 0) }
    }

    private var conditionalObservations: [PriceObservation] {
        Array(product.observations
            .filter { $0.condition != .regular && !$0.isExpired }
            .sortedChronologically
            .reversed())
    }

    var body: some View {
        ScreenScaffold(
            backLabel: backLabel,
            topPadding: 0,
            trailing: {
                Button("Edit") { showEdit = true }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            },
            footer: {
                if series.count <= 1, primary != nil {
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

                if let savedMessage {
                    SavedBanner(text: savedMessage, undo: undoLast)
                        .padding(.top, 14)
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
                        Text("\(primary.condition == .regular ? "Regular price" : primary.conditionLine) · \(primary.source.title)")
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

                    if series.count > 1 {
                        PrimaryButton(title: "Record a price") { showRecord = true }
                            .padding(.top, 18)
                        SecondaryButton(title: "No change · record today", action: recordNoChange)
                    } else {
                        SecondaryButton(title: "No change · record today", action: recordNoChange)
                            .padding(.top, 12)
                    }

                    SectionTitle(text: "Price history", actionTitle: "History") {
                        router.push(.history(product, store, .regular))
                    }
                    .padding(.top, 26)

                    NavigationLink(value: AppRoute.priceOverTime(product, store)) {
                        PriceChartView(observations: series)
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)

                    Text(series.count == 1
                        ? "1 observation · No estimates between dates"
                        : "\(series.count) observations · No estimates between dates")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 8)

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

                        InfoText(text: "\(currency) · Regular · Prices may have changed")
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
                        SecondaryButton(title: "History") {
                            router.push(.history(product, store, .regular))
                        }
                        SecondaryButton(title: "Statistics") {
                            router.push(.statistics(product, store))
                        }
                    }
                    .padding(.top, 16)
                } else {
                    PriceEmptyState { showRecord = true }
                        .padding(.top, 24)

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
        .fullScreenCover(isPresented: $showEdit) {
            ProductEditView(product: product) {
                product.isArchived = true
                product.archivedAt = .now
                try? context.save()
                showEdit = false
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordPriceView(product: product, initialStore: primaryStore) { observation in
                savedObservation = observation
                savedMessage = "Price saved · \(Format.relativeAge(observation.observedAt))"
            }
        }
    }

    private func recordNoChange() {
        guard let primary, let store = primary.store else { return }
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
        try? context.save()
        savedObservation = observation
        savedMessage = "Recorded today · No change"
    }

    private func undoLast() {
        guard let savedObservation else { return }
        context.delete(savedObservation)
        try? context.save()
        self.savedObservation = nil
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
                Text("\(Format.dateAndAge(item.observation.observedAt))\(item.observation.isExpired ? " · Expired offer" : "")")
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

    @State private var name = ""
    @State private var brand = ""
    @State private var variety = ""
    @State private var isFavorite = false
    @State private var showArchiveAlert = false
    @State private var showValidation = false

    var body: some View {
        ScreenScaffold(
            title: "Edit product",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
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

                SecondaryButton(title: "Archive product…", color: Theme.error) {
                    showArchiveAlert = true
                }
                .padding(.top, 12)
                .alert("Stop tracking this product?", isPresented: $showArchiveAlert) {
                    Button("Keep tracking", role: .cancel) {}
                    Button("Archive", role: .destructive, action: onArchive)
                } message: {
                    Text("It will leave the active Journal and entry pickers. Its history, statistics and backup data will be kept.")
                }
            }
            .onAppear {
                name = product.name
                brand = product.brand
                variety = product.variety
                isFavorite = product.isFavorite
            }
        }
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
        try? context.save()
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

                VStack(spacing: 0) {
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
                    VStack(spacing: 0) {
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
