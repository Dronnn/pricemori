import SwiftUI
import SwiftData

struct ObservationSnapshot {
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
            price: price,
            currencyCode: currencyCode,
            observedAt: observedAt,
            createdAt: createdAt,
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
            product: product,
            store: store
        )
    }
}

struct HistoryView: View {
    let product: Product
    var store: StoreLocation?
    var condition: ObservationCondition = .regular
    var backLabel: String = "Product"

    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context

    @State private var showEarlier = false
    @State private var earlierObservation: PriceObservation?
    @State private var earlierMessage: String?
    @State private var deletedSnapshot: ObservationSnapshot?
    @State private var deletedStore: StoreLocation?
    @State private var deletedMessage: String?

    private var scopedStore: StoreLocation? {
        store ?? product.latestRegularObservation?.store
    }

    private var currency: String {
        guard let scopedStore else { return "AMD" }
        return PriceMath.latestObservation(for: product, store: scopedStore, condition: condition)?.currencyCode ?? "AMD"
    }

    private var observations: [PriceObservation] {
        guard let scopedStore else { return [] }
        return Array(product.observations
            .filter {
                $0.store?.id == scopedStore.id
                    && $0.condition == condition
                    && $0.currencyCode == currency
            }
            .sortedChronologically
            .reversed())
    }

    private var unitLabel: String {
        observations.last?.baseUnitSymbol ?? "kg"
    }

    var body: some View {
        ScreenScaffold(
            title: "History",
            backLabel: backLabel,
            topPadding: 20,
            footer: {
                if condition == .regular {
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

                Text("Unit price · \(currency) / \(unitLabel) · \(condition.shortTitle)")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.top, 4)

                if let earlierMessage {
                    SavedBanner(text: earlierMessage, undo: undoEarlier)
                        .padding(.top, 14)
                }
                if let deletedMessage {
                    SavedBanner(text: deletedMessage, undo: undoDeletion)
                        .padding(.top, 14)
                }

                HStack(spacing: 10) {
                    SegmentedChip(title: "List", isSelected: true) {}
                    SegmentedChip(title: "Chart", isSelected: false) {
                        if let scopedStore {
                            router.push(.priceOverTime(product, scopedStore))
                        }
                    }
                }
                .padding(.top, 20)

                VStack(spacing: 0) {
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
                                Text("\(Format.date(observation.observedAt)) · \(observation.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.money(observation.price, currency: observation.currencyCode)) \(observation.currencyCode) / \(observation.baseUnitSymbol ?? "package")")
                                    .font(AppFont.inter(16, .medium))
                                    .foregroundStyle(Theme.primaryText)
                                Text("\(observation.packagePriceLine) · \(observation.source.title)")
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
                    InfoText(text: "No \(condition.shortTitle.lowercased()) observations at this branch yet.")
                        .padding(.top, 24)
                }
            }
        }
        .fullScreenCover(isPresented: $showEarlier) {
            if let scopedStore {
                EarlierPriceView(product: product, store: scopedStore) { observation in
                    earlierObservation = observation
                    earlierMessage = "Earlier price added · \(Format.date(observation.observedAt)). Latest remains \(latestText)."
                }
            }
        }
    }

    private var latestText: String {
        guard let latest = observations.first, let unitPrice = latest.unitPrice else { return "" }
        return "\(Format.number(unitPrice, maxFraction: 2)) \(latest.currencyCode) / \(latest.baseUnitSymbol ?? "")"
    }

    private func undoEarlier() {
        guard let earlierObservation else { return }
        context.delete(earlierObservation)
        try? context.save()
        self.earlierObservation = nil
        earlierMessage = nil
    }

    private func undoDeletion() {
        guard let deletedSnapshot, let deletedStore else { return }
        let restored = deletedSnapshot.makeObservation(product: product, store: deletedStore)
        context.insert(restored)
        try? context.save()
        self.deletedSnapshot = nil
        self.deletedStore = nil
        deletedMessage = nil
    }
}

struct ObservationDetailView: View {
    let product: Product
    let observation: PriceObservation
    var onDelete: (ObservationSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showCorrect = false
    @State private var showDeleteAlert = false
    @State private var showRecord = false

    private var previous: PriceObservation? {
        PriceMath.previousComparable(for: observation, among: product.observations)
    }

    private var change: PriceChange? {
        guard let previous else { return nil }
        return PriceMath.change(current: observation, previous: previous)
    }

    var body: some View {
        ScreenScaffold(
            title: "Observation",
            backLabel: "History",
            trailing: {
                HeaderActionButton(title: "Correct") { showCorrect = true }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(product.displayName)
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
                    SecondaryButton(title: "Record a new price") { showRecord = true }
                    SecondaryButton(title: "Correct this observation") { showCorrect = true }
                    SecondaryButton(title: "Delete observation…", color: Theme.error) { showDeleteAlert = true }
                }
                .padding(.top, 24)
            }
        }
        .fullScreenCover(isPresented: $showCorrect) {
            CorrectEntryView(observation: observation)
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordPriceView(product: product, initialStore: observation.store) { _ in }
        }
        .alert("Delete this observation?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let snapshot = ObservationSnapshot(observation)
                context.delete(observation)
                try? context.save()
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

    @State private var draft = ObservationDraft()
    @State private var showBasis = false
    @State private var showDateSource = false
    @State private var showValidation = false
    @State private var didLoad = false

    private var latest: PriceObservation? {
        PriceMath.latestObservation(for: product, store: store, condition: .regular)
    }

    var body: some View {
        ScreenScaffold(
            title: "Earlier price",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
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
                    FormRow(label: "Package · \(draft.quantityText) \(draft.unit.symbol)", value: "", detail: draft.unitPricePreviewText) {
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
            }
            .fullScreenCover(isPresented: $showBasis) { PriceBasisView(draft: $draft) }
            .fullScreenCover(isPresented: $showDateSource) { DateSourceView(draft: $draft) }
        }
    }

    private var latestText: String {
        guard let latest, let unitPrice = latest.unitPrice else { return "the same" }
        return "\(Format.number(unitPrice, maxFraction: 2)) \(latest.currencyCode) / \(latest.baseUnitSymbol ?? "")"
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
        try? context.save()
        onSaved(observation)
        dismiss()
    }
}

struct CorrectEntryView: View {
    let observation: PriceObservation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var draft = ObservationDraft()
    @State private var showBasis = false
    @State private var showDateSource = false
    @State private var showValidation = false
    @State private var didLoad = false

    var body: some View {
        ScreenScaffold(
            title: "Correct entry",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
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
                    Text("Price in \(draft.currencyCode) *")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "0", text: $draft.priceText, keyboard: .decimalPad)
                    Text("Saved amount: \(Format.money(observation.price, currency: observation.currencyCode)) \(observation.currencyCode) · Correct if needed")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(spacing: 0) {
                    FormRow(label: "Package · \(draft.quantityText) \(draft.unit.symbol)", value: "", detail: draft.unitPricePreviewText) {
                        showBasis = true
                    }
                    SeparatorLine()
                    FormRow(label: Format.dateAndAge(draft.observedAt), value: "", detail: draft.source.title) {
                        showDateSource = true
                    }
                }

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
            }
            .fullScreenCover(isPresented: $showBasis) { PriceBasisView(draft: $draft) }
            .fullScreenCover(isPresented: $showDateSource) { DateSourceView(draft: $draft) }
        }
    }

    private func save() {
        guard draft.hasValidPrice, draft.hasValidQuantity, let price = draft.price else {
            showValidation = true
            return
        }
        observation.price = Format.roundedForCurrency(price, currency: draft.currencyCode)
        observation.currencyCode = draft.currencyCode
        observation.observedAt = draft.observedAt
        observation.packageQuantity = draft.sizeKnown ? draft.quantity : nil
        observation.packageUnit = draft.sizeKnown ? draft.unit : nil
        observation.sizeKnown = draft.sizeKnown && draft.quantity != nil
        observation.isLoose = draft.isLoose
        observation.source = draft.source
        observation.updatedAt = .now
        try? context.save()
        dismiss()
    }
}
