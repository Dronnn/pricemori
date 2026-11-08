import SwiftUI
import SwiftData

struct RecordPriceView: View {
    let product: Product
    var initialStore: StoreLocation?
    let onSaved: (PriceObservation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var draft = ObservationDraft()
    @State private var selectedStore: StoreLocation?
    @State private var showBasis = false
    @State private var showConditions = false
    @State private var showDateSource = false
    @State private var showCurrency = false
    @State private var showStorePicker = false
    @State private var showValidation = false
    @State private var showDiscard = false
    @State private var didLoad = false

    private var latestAtStore: PriceObservation? {
        guard let selectedStore else { return nil }
        return PriceMath.latestObservation(for: product, store: selectedStore, condition: .regular)
    }

    private var priceLabel: String {
        if draft.condition == .multiBuy {
            return L10n.format("Total price for %lld packages", max(2, draft.multiBuyMinimum))
        }
        return L10n.string("Price for this package")
    }

    private var packageTitle: String {
        if !draft.sizeKnown { return L10n.string("Package · Unknown") }
        let amount = "\(draft.quantityText) \(draft.unit.symbol)"
        if draft.isLoose { return L10n.format("Per unit · %@", amount) }
        return L10n.format("Per package · %@", amount)
    }

    private var packageDetail: String {
        if let preview = draft.unitPricePreviewText {
            return L10n.format("Unit price: %@", preview)
        }
        return L10n.string("Enter an amount to see the unit price")
    }

    private var hasDraftChanges: Bool {
        !draft.priceText.trimmingCharacters(in: .whitespaces).isEmpty
            || draft.condition != .regular
            || !Calendar.current.isDateInToday(draft.observedAt)
    }

    var body: some View {
        ScreenScaffold(
            title: "Record price",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { cancelTapped() },
            topPadding: 8,
            footer: {
                PrimaryButton(title: "Save observation") { save() }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)

                Button {
                    showStorePicker = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedStore?.displayName ?? "Choose a store")
                                .font(AppFont.inter(16, .medium))
                                .foregroundStyle(Theme.primaryText)
                            Text(selectedStore.map { $0.city.isEmpty ? "This branch only" : "\($0.city) · This branch only" } ?? "Choose the branch where you saw this price")
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.bottom, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SeparatorLine()

                VStack(alignment: .leading, spacing: 8) {
                    Text(priceLabel)
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(spacing: 10) {
                        OutlinedField(placeholder: "0", text: $draft.priceText, keyboard: .decimalPad)
                        Button {
                            showCurrency = true
                        } label: {
                            HStack {
                                Text(draft.currencyCode)
                                    .font(AppFont.inter(16))
                                    .foregroundStyle(Theme.primaryText)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(width: 100, height: 48)
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 0) {
                    FormRow(label: packageTitle, value: "", detail: packageDetail) { showBasis = true }
                    SeparatorLine()
                    FormRow(
                        label: Format.relativeThenDate(draft.observedAt),
                        value: "",
                        detail: draft.source.title
                    ) { showDateSource = true }
                    SeparatorLine()
                    FormRow(
                        label: draft.condition == .regular ? "Regular price" : draft.condition.shortTitle,
                        value: "",
                        detail: "Offer conditions"
                    ) { showConditions = true }
                }

                if let latestAtStore {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.format("Previous at this branch: %@ %@ / %@", latestAtStore.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.money(latestAtStore.price, currency: latestAtStore.currencyCode), latestAtStore.currencyCode, latestAtStore.baseUnitSymbol ?? L10n.string("package")))
                        Text(Format.dateAndAge(latestAtStore.observedAt))
                    }
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.secondaryText)
                }

                if showValidation {
                    Text(validationMessage)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }
            }
            .onAppear(perform: loadInitial)
            .fullScreenCover(isPresented: $showBasis) { PriceBasisView(draft: $draft) }
            .fullScreenCover(isPresented: $showConditions) { ConditionsView(draft: $draft) }
            .fullScreenCover(isPresented: $showDateSource) { DateSourceView(draft: $draft) }
            .fullScreenCover(isPresented: $showCurrency) { CurrencyPickerView(draft: $draft) }
            .fullScreenCover(isPresented: $showStorePicker) {
                StorePickerView(product: product, selection: $selectedStore) { store in
                    selectedStore = store
                    loadTemplate(for: store)
                }
            }
            .fullScreenCover(isPresented: $showDiscard) {
                DiscardDraftView(
                    onKeepEditing: { showDiscard = false },
                    onDiscard: {
                        showDiscard = false
                        dismiss()
                    }
                )
            }
        }
    }

    private var validationMessage: String {
        if selectedStore == nil { return L10n.string("Choose a store for this observation.") }
        if !draft.hasValidPrice { return L10n.string("Enter an amount greater than zero.") }
        if !draft.hasValidQuantity { return L10n.string("Enter a package amount greater than zero.") }
        return ""
    }

    private func loadInitial() {
        guard !didLoad else { return }
        didLoad = true
        selectedStore = initialStore ?? stores.first { !$0.isArchived }
        draft.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "AMD"
        draft.source = ObservationSource(rawValue: UserDefaults.standard.string(forKey: "defaultSource") ?? "") ?? .shelf
        if let selectedStore {
            loadTemplate(for: selectedStore)
        }
    }

    private func loadTemplate(for store: StoreLocation) {
        let latest = PriceMath.latestObservation(for: product, store: store, condition: .regular)
            ?? product.latestRegularObservation
        if let latest {
            draft.applyTemplate(from: latest)
            draft.observedAt = .now
            draft.condition = .regular
            draft.conditionLabel = ""
            draft.conditionEndDate = nil
            draft.multiBuyMinimum = 1
        }
    }

    private func cancelTapped() {
        if hasDraftChanges {
            showDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard let selectedStore, draft.hasValidPrice, draft.hasValidQuantity,
              let observation = draft.makeObservation(product: product, store: selectedStore)
        else {
            showValidation = true
            return
        }
        context.insert(observation)
        try? context.save()
        onSaved(observation)
        dismiss()
    }
}

struct StorePickerView: View {
    let product: Product
    @Binding var selection: StoreLocation?
    var onSelect: (StoreLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var search = ""
    @State private var showAdd = false

    private var activeStores: [StoreLocation] {
        stores.filter { !$0.isArchived }
    }

    private var filtered: [StoreLocation] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return activeStores }
        return activeStores.filter { $0.displayName.lowercased().contains(query) || $0.city.lowercased().contains(query) }
    }

    private var previouslyUsed: [StoreLocation] {
        filtered.filter { store in
            product.observations.contains { $0.store?.id == store.id }
        }
    }

    private var otherStores: [StoreLocation] {
        filtered.filter { store in
            !product.observations.contains { $0.store?.id == store.id }
        }
    }

    var body: some View {
        ScreenScaffold(title: "Choose a store", backLabel: "Back") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find a saved location")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    TextField("Search stores or branches", text: $search)
                        .font(AppFont.inter(16))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                        .autocorrectionDisabled()
                }

                if !previouslyUsed.isEmpty {
                    FieldLabel(text: "Previously used for this product")
                    VStack(spacing: 0) {
                        ForEach(previouslyUsed) { store in
                            Button {
                                choose(store)
                            } label: {
                                StorePickerRow(
                                    store: store,
                                    observation: PriceMath.latestObservation(for: product, store: store, condition: .regular),
                                    isSelected: selection?.id == store.id
                                )
                            }
                            .buttonStyle(.plain)
                            SeparatorLine()
                        }
                    }
                }

                if !otherStores.isEmpty {
                    FieldLabel(text: "All stores")
                    VStack(spacing: 0) {
                        ForEach(otherStores) { store in
                            Button {
                                choose(store)
                            } label: {
                                StorePickerRow(
                                    store: store,
                                    observation: PriceMath.latestObservation(for: product, store: store, condition: .regular),
                                    isSelected: selection?.id == store.id
                                )
                            }
                            .buttonStyle(.plain)
                            SeparatorLine()
                        }
                    }
                }

                Button {
                    showAdd = true
                } label: {
                    Text("+ Add another store")
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                InfoText(text: "Archived locations are excluded from this picker. Restore one from Stores to use it.")
            }
        }
        .fullScreenCover(isPresented: $showAdd) {
            StoreFormView(mode: .add) { store in
                context.insert(store)
                try? context.save()
                showAdd = false
                choose(store)
            }
        }
    }

    private func choose(_ store: StoreLocation) {
        selection = store
        onSelect(store)
        dismiss()
    }
}

struct StorePickerRow: View {
    let store: StoreLocation
    let observation: PriceObservation?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if isSelected {
                Text("✓")
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 18)
            } else {
                Color.clear.frame(width: 18, height: 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(store.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                if let observation {
                    Text("\(observation.unitPriceLine ?? observation.packagePriceLine) · \(Format.date(observation.observedAt))")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                } else if !store.city.isEmpty {
                    Text(store.city)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
