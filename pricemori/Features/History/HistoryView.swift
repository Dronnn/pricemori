import SwiftUI
import SwiftData

struct ObservationSnapshot {
    let id: UUID
    let originalProduct: Product?
    let originalStore: StoreLocation?
    let updatedAt: Date
    let price: Decimal
    let currencyCode: String
    let observedAt: Date
    let createdAt: Date
    let packageQuantity: Decimal?
    let packageUnit: MeasurementUnit?
    let sizeKnown: Bool
    let isLoose: Bool
    let condition: ObservationCondition
    let conditionLabel: String
    let conditionEndDate: Date?
    let multiBuyMinimum: Int
    let source: ObservationSource
    let note: String

    init(_ observation: PriceObservation) {
        id = observation.id
        originalProduct = observation.product
        originalStore = observation.store
        updatedAt = observation.updatedAt
        price = observation.price
        currencyCode = observation.currencyCode
        observedAt = observation.observedAt
        createdAt = observation.createdAt
        packageQuantity = observation.packageQuantity
        packageUnit = observation.packageUnit
        sizeKnown = observation.sizeKnown
        isLoose = observation.isLoose
        condition = observation.condition
        conditionLabel = observation.conditionLabel
        conditionEndDate = observation.conditionEndDate
        multiBuyMinimum = observation.multiBuyMinimum
        source = observation.source
        note = observation.note
    }

    func makeObservation(product: Product, store: StoreLocation) -> PriceObservation {
        PriceObservation(
            id: id,
            price: price,
            currencyCode: currencyCode,
            observedAt: observedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            packageQuantity: packageQuantity,
            packageUnit: packageUnit,
            sizeKnown: sizeKnown,
            isLoose: isLoose,
            condition: condition,
            conditionLabel: conditionLabel,
            conditionEndDate: conditionEndDate,
            multiBuyMinimum: multiBuyMinimum,
            source: source,
            note: note,
            product: originalProduct ?? product,
            store: originalStore ?? store
        )
    }
}

struct ObservationRemoval {
    let snapshot: ObservationSnapshot
    let store: StoreLocation

    func restore(product: Product, context: ModelContext) {
        context.insert(snapshot.makeObservation(product: product, store: store))
    }
}

struct HistoryView: View {
    let product: Product
    var store: StoreLocation?
    var condition: ObservationCondition = .regular
    var backLabel: String = "Product"
    var referenceID: UUID? = nil
    var currencyFilter: String? = nil

    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var saveError = false

    @State private var showEarlier = false
    @State private var earlierObservationID: UUID?
    @State private var earlierMessage: String?
    @State private var deletedSnapshot: ObservationSnapshot?
    @State private var deletedStore: StoreLocation?
    @State private var deletedMessage: String?

    private var earlierObservation: PriceObservation? { product.observations.first { $0.id == earlierObservationID } }

    private var scopedStore: StoreLocation? {
        store ?? product.latestObservation?.store
    }

    private var reference: PriceObservation? {
        product.observations.first { $0.id == referenceID && $0.condition == condition && (currencyFilter == nil || $0.currencyCode == currencyFilter) }
    }

    private var currency: String {
        if let currencyFilter { return currencyFilter }
        if let reference { return reference.currencyCode }
        guard let scopedStore else { return "AMD" }
        return PriceMath.latestObservation(for: product, store: scopedStore, condition: condition)?.currencyCode ?? "AMD"
    }

    private var observations: [PriceObservation] {
        guard let scopedStore else { return [] }
        return Array(product.observations
            .filter { observation in
                observation.store?.id == scopedStore.id
                    && observation.condition == condition
                    && observation.currencyCode == currency
                    && (reference.map { PriceMath.sameOffer(observation, $0) } ?? true)
            }
            .sortedChronologically
            .reversed())
    }

    private var unitLabel: String {
        observations.last?.baseUnitSymbol ?? "kg"
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "History",
            backLabel: backLabel,
            topPadding: 20,
            trailing: {
                HeaderActionButton(title: "All observations") { router.push(.allHistory(product)) }
            },
            footer: {
                if condition == .regular, !product.isArchived {
                    SecondaryButton(title: "Record an earlier observation") {
                        showEarlier = true
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.displayName)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let scopedStore {
                    Text(scopedStore.displayName)
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                        .padding(.top, 10)
                }

                Text(currency + " · " + condition.shortTitle)
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 4)

                if let earlierMessage, earlierObservation != nil {
                    SavedBanner(text: earlierMessage, undo: undoEarlier)
                        .padding(.top, 14)
                }
                if let deletedMessage {
                    SavedBanner(text: deletedMessage, undo: undoDeletion)
                        .padding(.top, 14)
                }

                AdaptiveControlRow {
                    SegmentedChip(title: "List", isSelected: true) {}
                    SegmentedChip(title: "Chart", isSelected: false) {
                        if let scopedStore {
                            if let chartReference = reference ?? observations.first {
                                router.push(.scopedPriceOverTime(product, scopedStore, chartReference.id))
                            }
                        }
                    }
                    .disabled(observations.isEmpty)
                }
                .padding(.top, 20)

                LazyVStack(spacing: 0) {
                    ForEach(observations) { observation in
                        NavigationLink {
                            ObservationDetailView(
                                product: product,
                                observation: observation,
                                onDelete: { snapshot in
                                    deletedSnapshot = snapshot
                                    deletedStore = scopedStore
                                    deletedMessage = "Observation removed"
                                }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(Format.timestamp(observation.observedAt)) · \(observation.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.number(observation.effectivePackagePrice, maxFraction: 2)) \(observation.currencyCode) / \(observation.baseUnitSymbol ?? "package")")
                                    .font(AppFont.inter(16, .medium))
                                    .foregroundStyle(Theme.primaryText)
                                Text(observation.unitPrice == nil ? observation.source.title : "\(observation.packagePriceLine) · \(observation.source.title)")
                                    .font(AppFont.inter(14))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        SeparatorLine()
                    }
                }
                .padding(.top, 8)

                if observations.isEmpty {
                    InfoText(text: "No observations match this scope. Your saved prices are available in All observations.")
                        .padding(.top, 24)
                }
            }
        }
        .fullScreenCover(isPresented: $showEarlier) {
            if let scopedStore {
                NavigationStack {
                    EarlierPriceView(product: product, store: scopedStore) { observation in
                        earlierObservationID = observation.id
                        earlierMessage = L10n.format("Earlier price added · %@. Latest remains %@.", Format.date(observation.observedAt), latestText)
                    }
                }
            }
        }
    }

    private var latestText: String {
        guard let latest = observations.first else { return "" }
        return latest.unitPrice.map { "\(Format.number($0, maxFraction: 2)) \(latest.currencyCode) / \(latest.baseUnitSymbol ?? "unit")" } ?? latest.packagePriceLine
    }

    private func undoEarlier() {
        guard let earlierObservation else { return }
        context.delete(earlierObservation)
        guard context.saveReportingError(&saveError) else { return }
        earlierObservationID = nil
        earlierMessage = nil
    }

    private func undoDeletion() {
        guard let deletedSnapshot, let deletedStore else { return }
        let restored = deletedSnapshot.makeObservation(product: product, store: deletedStore)
        context.insert(restored)
        guard context.saveReportingError(&saveError) else { return }
        self.deletedSnapshot = nil
        self.deletedStore = nil
        deletedMessage = nil
    }
}

struct ObservationDetailView: View {
    let product: Product
    let observation: PriceObservation
    var backLabel: String = "History"
    var onDelete: (ObservationSnapshot) -> Void

    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveError = false

    @State private var showCorrect = false
    @State private var showDeleteAlert = false
    @State private var showRecord = false

    private var recordProduct: Product { observation.product ?? product }

    private var previous: PriceObservation? {
        PriceMath.previousComparable(for: observation, among: recordProduct.observations)
    }

    private var change: PriceChange? {
        guard let previous else { return nil }
        return PriceMath.change(current: observation, previous: previous)
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Observation",
            backLabel: backLabel,
            trailing: {
                HeaderActionButton(title: "Correct") { showCorrect = true }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(recordProduct.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(Format.number(observation.headlineAmount, maxFraction: 2))
                        .font(AppFont.serif(32))
                        .foregroundStyle(Theme.primaryText)
                    Text(observation.headlineUnit)
                        .font(AppFont.inter(16))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 14)

                Text(observation.packagePriceLine)
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 2)

                Text(observation.store?.displayName ?? "")
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.top, 16)

                Text("\(Format.timestamp(observation.observedAt))\n\(observation.source.title) · \(observation.condition == .regular ? "Regular price" : observation.conditionLine)")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .padding(.top, 4)

                if observation.condition == .multiBuy {
                    InfoText(text: observation.multiBuySummary)
                        .padding(.top, 10)
                }

                if let previous, let change {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Previous comparable at this branch")
                            .font(AppFont.inter(14, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Text("\(previous.unitPrice.map { Format.number($0, maxFraction: 2) } ?? "") \(previous.currencyCode) / \(previous.baseUnitSymbol ?? "") · \(Format.date(previous.observedAt))")
                        Text("\(change.amount > 0 ? "Up" : change.amount < 0 ? "Down" : "No change") \(change.amountText.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "−", with: "")) · \(Format.percent(change.percent)) over \(daysBetween(previous.observedAt, observation.observedAt)) days")
                    }
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 20)
                } else {
                    InfoText(text: "First comparable observation at this branch. No earlier price is known, so no change is calculated.")
                        .padding(.top, 20)
                }

                VStack(spacing: 2) {
                    if let store = observation.store {
                        SecondaryButton(title: "Chart this history") {
                            router.push(.scopedPriceOverTime(recordProduct, store, observation.id))
                        }
                    }
                    if !recordProduct.isArchived {
                        SecondaryButton(title: "Record a new price") { showRecord = true }
                    }
                    SecondaryButton(title: "Correct this observation") { showCorrect = true }
                    SecondaryButton(title: "Delete observation…", color: Theme.error) { showDeleteAlert = true }
                }
                .padding(.top, 24)
            }
        }
        .fullScreenCover(isPresented: $showCorrect) {
            NavigationStack { CorrectEntryView(observation: observation) }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordPriceView(product: recordProduct, initialStore: observation.store, initialObservation: observation) { _ in }
        }
        .alert("Delete this observation?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let snapshot = ObservationSnapshot(observation)
                context.delete(observation)
                guard context.saveReportingError(&saveError) else { return }
                onDelete(snapshot)
                dismiss()
            }
        } message: {
            Text("It will be removed from history and charts. You can undo this from History.")
        }
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}

struct EarlierPriceView: View {
    let product: Product
    let store: StoreLocation
    let onSaved: (PriceObservation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveError = false

    @State private var draft = ObservationDraft()
    @State private var showBasis = false
    @State private var showDateSource = false
    @State private var showValidation = false
    @State private var didLoad = false
    @State private var initialDraft: ObservationDraft?
    @State private var showDiscard = false

    private var latest: PriceObservation? {
        PriceMath.latestObservation(for: product, store: store, condition: .regular)
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Earlier price",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: {
                if let initialDraft, initialDraft != draft { showDiscard = true } else { dismiss() }
            },
            footer: {
                PrimaryButton(title: "Save earlier price") { save() }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                Text(store.displayName)
                    .font(AppFont.inter(15))
                    .foregroundStyle(Theme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Observed on")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    DatePicker("", selection: $draft.observedAt, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Theme.accent)
                        .environment(\.locale, Locale(identifier: "en_GB"))
                    Text("\(Format.timestamp(draft.observedAt)) · \(Format.relativeAge(draft.observedAt))")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Package price · \(draft.currencyCode)")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "0", text: $draft.priceText, keyboard: .decimalPad)
                }

                VStack(spacing: 0) {
                    FormRow(label: draft.sizeKnown ? "Package · \(draft.quantityText) \(draft.unit.symbol)" : "Package · Unknown", value: "", detail: draft.unitPricePreviewText) {
                        showBasis = true
                    }
                    SeparatorLine()
                    FormRow(label: Format.dateAndAge(draft.observedAt), value: "", detail: draft.source.title) {
                        showDateSource = true
                    }
                }

                if showValidation {
                    Text(validationMessage)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }

                InfoText(text: "Date is when you saw the price. This is an older observation; today’s latest price stays \(latestText).")
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                draft.observedAt = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
                draft.currencyCode = latest?.currencyCode ?? "AMD"
                draft.source = .shelf
                if let latest {
                    draft.quantityText = latest.packageQuantity.map(Format.inputText) ?? ""
                    draft.unit = latest.packageUnit ?? .kilogram
                    draft.sizeKnown = latest.sizeKnown
                    draft.isLoose = latest.isLoose
                }
                initialDraft = draft
            }
            .alert("Discard changes?", isPresented: $showDiscard) {
                Button("Discard draft", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showBasis) { PriceBasisView(draft: $draft) }
            .fullScreenCover(isPresented: $showDateSource) { DateSourceView(draft: $draft) }
        }
    }

    private var latestText: String {
        guard let latest else { return "the same" }
        return latest.unitPrice.map { "\(Format.number($0, maxFraction: 2)) \(latest.currencyCode) / \(latest.baseUnitSymbol ?? "unit")" } ?? latest.packagePriceLine
    }

    private var validationMessage: String {
        if !draft.hasValidPrice { return "Enter an amount greater than zero." }
        if let latest, draft.observedAt >= latest.observedAt {
            return "Choose a date before the latest observation."
        }
        return "Enter a package amount greater than zero."
    }

    private func save() {
        guard draft.hasValidPrice, draft.hasValidQuantity else {
            showValidation = true
            return
        }
        if let latest, draft.observedAt >= latest.observedAt {
            showValidation = true
            return
        }
        guard let observation = draft.makeObservation(product: product, store: store) else {
            showValidation = true
            return
        }
        context.insert(observation)
        guard context.saveReportingError(&saveError) else { return }
        onSaved(observation)
        dismiss()
    }
}

struct CorrectEntryView: View {
    let observation: PriceObservation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @Query(sort: \Product.createdAt) private var products: [Product]
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]
    @State private var selectedProduct: Product?
    @State private var selectedStore: StoreLocation?
    @State private var showLocation = false

    @State private var draft = ObservationDraft()
    @State private var showBasis = false
    @State private var showDateSource = false
    @State private var showConditions = false
    @State private var showCurrency = false
    @State private var showValidation = false
    @State private var didLoad = false
    @State private var initialDraft: ObservationDraft?
    @State private var showDiscard = false

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Correct entry",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: {
                if hasChanges { showDiscard = true } else { dismiss() }
            },
            footer: {
                PrimaryButton(title: "Save correction") { save() }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Editing \(Format.timestamp(observation.observedAt))")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)

                InfoText(text: "Correct a mistake in this saved record. For a newly observed price, create a new observation.")

                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.condition == .multiBuy ? L10n.format("Total price for %lld packages", draft.multiBuyMinimum) : L10n.format("Price in %@ *", draft.currencyCode))
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "0", text: $draft.priceText, keyboard: .decimalPad)
                    Text("Saved amount: \(Format.money(observation.price, currency: observation.currencyCode)) \(observation.currencyCode) · Correct if needed")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(spacing: 0) {
                    FormRow(label: draft.sizeKnown ? "Package · \(draft.quantityText) \(draft.unit.symbol)" : "Package · Unknown", value: "", detail: draft.unitPricePreviewText) {
                        showBasis = true
                    }
                    SeparatorLine()
                    FormRow(label: Format.dateAndAge(draft.observedAt), value: "", detail: draft.source.title) {
                        showDateSource = true
                    }
                }

                FormRow(label: "Product and branch", value: "", detail: "\(selectedProduct?.displayName ?? "") · \(selectedStore?.displayName ?? "")") {
                    showLocation = true
                }
                FormRow(label: "Currency", value: draft.currencyCode, detail: nil) { showCurrency = true }
                FormRow(label: draft.condition.title, value: "", detail: draft.conditionLabel.isEmpty ? nil : draft.conditionLabel) { showConditions = true }

                if showValidation {
                    Text("Enter an amount greater than zero and a package amount.")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }

                InfoText(text: "\(observation.store?.displayName ?? "") · \(observation.conditionLine) · \(observation.source.shortTitle)")
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                draft.priceText = Format.inputText(observation.price)
                draft.currencyCode = observation.currencyCode
                draft.quantityText = observation.packageQuantity.map(Format.inputText) ?? ""
                draft.unit = observation.packageUnit ?? .kilogram
                draft.sizeKnown = observation.sizeKnown
                draft.isLoose = observation.isLoose
                draft.observedAt = observation.observedAt
                draft.source = observation.source
                draft.note = observation.note
                draft.condition = observation.condition
                draft.conditionLabel = observation.conditionLabel
                draft.multiBuyMinimum = observation.multiBuyMinimum
                draft.conditionEndDate = observation.conditionEndDate
                selectedProduct = observation.product
                selectedStore = observation.store
                initialDraft = draft
            }
            .alert("Discard changes?", isPresented: $showDiscard) {
                Button("Discard draft", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showLocation) {
                CorrectionLocationView(products: products, stores: stores, product: $selectedProduct, store: $selectedStore)
            }
            .fullScreenCover(isPresented: $showConditions) { ConditionsView(draft: $draft) }
            .fullScreenCover(isPresented: $showCurrency) { CurrencyPickerView(draft: $draft) }
            .fullScreenCover(isPresented: $showBasis) { PriceBasisView(draft: $draft) }
            .fullScreenCover(isPresented: $showDateSource) { DateSourceView(draft: $draft) }
        }
    }

    private var hasChanges: Bool {
        (initialDraft.map { $0 != draft } ?? false)
            || selectedProduct?.id != observation.product?.id || selectedStore?.id != observation.store?.id
    }

    private func save() {
        guard let selectedProduct, let selectedStore,
              draft.applyCorrection(to: observation, product: selectedProduct, store: selectedStore) else {
            showValidation = true
            return
        }
        guard context.saveReportingError(&saveError) else { return }
        dismiss()
    }
}
