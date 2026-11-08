import SwiftUI
import SwiftData

enum AddProductMode {
    case onboarding
    case full
}

struct AddProductFlow: View {
    let mode: AddProductMode
    var initialName: String = ""
    let onComplete: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ProductDraft()
    @State private var showPrice = false

    var body: some View {
        NavigationStack {
            AddProductView(
                draft: $draft,
                mode: mode,
                onCancel: { dismiss() },
                onContinue: {
                    if mode == .onboarding { draft.parseCombinedName() }
                    showPrice = true
                },
                onSaveWithoutPrice: {
                    let product = draft.makeProduct()
                    context.insert(product)
                    try? context.save()
                    onComplete(product)
                    dismiss()
                }
            )
            .navigationDestination(isPresented: $showPrice) {
                FirstPriceView(
                    productDraft: draft,
                    onBack: { showPrice = false },
                    onSaved: { product in
                        onComplete(product)
                        dismiss()
                    }
                )
            }
        }
        .onAppear {
            if draft.name.isEmpty { draft.name = initialName }
        }
    }
}

struct AddProductView: View {
    @Binding var draft: ProductDraft
    let mode: AddProductMode
    let onCancel: () -> Void
    let onContinue: () -> Void
    let onSaveWithoutPrice: () -> Void

    @State private var showValidation = false

    private var nameIsValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScreenScaffold(
            title: "Add product",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: onCancel,
            topPadding: 20,
            footer: {
                VStack(spacing: 0) {
                    PrimaryButton(title: "Continue to price") {
                        if nameIsValid { onContinue() } else { showValidation = true }
                    }
                    if mode == .full {
                        SecondaryButton(title: "Save product without a price", action: onSaveWithoutPrice)
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                if mode == .onboarding {
                    Text("What price do you\nwant to remember?")
                        .font(AppFont.serif(32))
                        .foregroundStyle(Theme.primaryText)
                        .lineSpacing(2)
                        .padding(.bottom, 2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .onboarding ? "Product name" : "Product name *")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Buckwheat · Brand X", text: $draft.name)
                }

                if mode == .full {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Brand or model")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                        OutlinedField(placeholder: "Brand X", text: $draft.brand)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Variety / identifying detail")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                        OutlinedField(placeholder: "Whole grain", text: $draft.variety)
                    }
                }

                if showValidation && !nameIsValid {
                    Text("Enter a product name to continue.")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }

                if mode == .onboarding {
                    InfoText(text: "Include the brand or variety if it matters. You can change the name later.")
                    InfoText(text: "Start with one product. Its package size and store are recorded with the price.")
                        .padding(.top, 42)
                } else {
                    InfoText(text: "Your saved stores will be available at the next step. Package size is recorded with the price.")
                        .padding(.top, 32)
                }
            }
        }
    }
}

struct FirstPriceView: View {
    let productDraft: ProductDraft
    let onBack: () -> Void
    let onSaved: (Product) -> Void

    @Environment(\.modelContext) private var context
    @Query private var stores: [StoreLocation]

    @State private var draft = ObservationDraft()
    @State private var storeName = ""
    @State private var branch = ""
    @State private var showBasis = false
    @State private var showConditions = false
    @State private var showDateSource = false
    @State private var showCurrency = false
    @State private var showValidation = false

    private var priceLabel: String {
        draft.condition == .multiBuy
            ? L10n.format("Total price for %lld packages", max(2, draft.multiBuyMinimum))
            : L10n.string("Package price")
    }

    private var packageTitle: String {
        if !draft.sizeKnown { return L10n.string("Package · Unknown") }
        let amount = "\(draft.quantityText) \(draft.unit.symbol)"
        if draft.isLoose { return L10n.format("Per unit · %@", amount) }
        return L10n.format("Package · %@", amount)
    }

    private var packageDetail: String {
        if let preview = draft.unitPricePreviewText {
            return L10n.format("%@ · %@", preview, L10n.string("Change size or basis"))
        }
        return L10n.string("Change size or basis")
    }

    var body: some View {
        ScreenScaffold(
            title: "First price",
            backLabel: "Product",
            backAction: onBack,
            topPadding: 8,
            footer: {
                PrimaryButton(title: "Save first price") { save() }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text(productDraft.displayName)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(priceLabel)
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    HStack(spacing: 10) {
                        OutlinedField(placeholder: "320", text: $draft.priceText, keyboard: .decimalPad)
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

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Store name")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                        OutlinedField(placeholder: "SAS", text: $storeName)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Branch / location")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                        OutlinedField(placeholder: "Komitas 12", text: $branch)
                    }
                }

                VStack(spacing: 0) {
                    FormRow(label: packageTitle, value: "", detail: packageDetail) { showBasis = true }
                    SeparatorLine()
                    FormRow(
                        label: Format.relativeThenDate(draft.observedAt),
                        value: "",
                        detail: L10n.format("%@ · %@", draft.source.title, L10n.string("Change date or source"))
                    ) { showDateSource = true }
                    SeparatorLine()
                    FormRow(
                        label: draft.condition == .regular ? "Regular price" : draft.condition.shortTitle,
                        value: "",
                        detail: draft.condition == .regular ? "Add card or multi-buy conditions" : draft.condition.shortTitle
                    ) { showConditions = true }
                }

                if showValidation {
                    Text(validationMessage)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }

            }
            .onAppear {
                if draft.priceText.isEmpty {
                    draft.currencyCode = UserDefaults.standard.string(forKey: "currencyCode") ?? "AMD"
                    draft.source = ObservationSource(rawValue: UserDefaults.standard.string(forKey: "defaultSource") ?? "") ?? .shelf
                }
            }
            .fullScreenCover(isPresented: $showBasis) { PriceBasisView(draft: $draft) }
            .fullScreenCover(isPresented: $showConditions) { ConditionsView(draft: $draft) }
            .fullScreenCover(isPresented: $showDateSource) { DateSourceView(draft: $draft) }
            .fullScreenCover(isPresented: $showCurrency) { CurrencyPickerView(draft: $draft) }
        }
    }

    private var validationMessage: String {
        if !productDraft.isValid { return L10n.string("Enter a product name before saving.") }
        if !draft.hasValidPrice { return L10n.string("Enter an amount greater than zero.") }
        if !draft.hasValidQuantity { return L10n.string("Enter a package amount greater than zero.") }
        if storeName.trimmingCharacters(in: .whitespaces).isEmpty || branch.trimmingCharacters(in: .whitespaces).isEmpty {
            return L10n.string("Enter the store name and branch.")
        }
        return ""
    }

    private func save() {
        guard productDraft.isValid, draft.hasValidPrice, draft.hasValidQuantity,
              !storeName.trimmingCharacters(in: .whitespaces).isEmpty,
              !branch.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            showValidation = true
            return
        }

        let product = productDraft.makeProduct()
        let cleanedName = storeName.trimmingCharacters(in: .whitespaces)
        let cleanedBranch = branch.trimmingCharacters(in: .whitespaces)
        let existingStore = stores.first {
            !$0.isArchived
                && $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame
                && $0.branch.caseInsensitiveCompare(cleanedBranch) == .orderedSame
        }
        let store = existingStore ?? StoreLocation(
            name: cleanedName,
            branch: cleanedBranch,
            city: "",
            note: ""
        )

        guard let observation = draft.makeObservation(product: product, store: store) else {
            showValidation = true
            return
        }

        context.insert(product)
        if existingStore == nil { context.insert(store) }
        context.insert(observation)
        try? context.save()
        onSaved(product)
    }
}

struct StoreFormView: View {
    enum Mode {
        case add
        case edit(StoreLocation)
    }

    let mode: Mode
    let onSave: (StoreLocation) -> Void
    var onArchive: ((StoreLocation) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query private var stores: [StoreLocation]

    @State private var name = ""
    @State private var branch = ""
    @State private var city = ""
    @State private var note = ""
    @State private var duplicate: StoreLocation?
    @State private var showDuplicateAlert = false
    @State private var showArchiveAlert = false
    @State private var showValidation = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit store" : "Add store"
    }

    var body: some View {
        ScreenScaffold(
            title: title,
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: isEditing ? "Save location" : "Use this store") { save() }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Store name *")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "SAS", text: $name)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Branch / address *")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Komitas 12", text: $branch)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("City or area")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Yerevan", text: $city)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note (optional)")
                        .font(AppFont.inter(13))
                        .foregroundStyle(Theme.secondaryText)
                    OutlinedField(placeholder: "Near home", text: $note)
                }

                if showValidation {
                    Text("Enter the store name and branch.")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.error)
                }

                if !storeDisplayName.isEmpty {
                    InfoText(text: L10n.format("This location will be saved as %@.", storeDisplayName))
                }

                InfoText(text: "Save each branch separately. Two branches of the same chain may charge different prices.")

                if isEditing, let store {
                    SecondaryButton(title: "Archive location…", color: Theme.error) {
                        showArchiveAlert = true
                    }
                    .padding(.top, 8)
                    .alert("Archive this location?", isPresented: $showArchiveAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Archive", role: .destructive) {
                            onArchive?(store)
                        }
                    } message: {
                        Text("This branch will leave active store pickers. Its earlier observations and charts will be kept.")
                    }
                }
            }
            .onAppear(perform: load)
            .alert("Location exists", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Use saved location") {
                    if let duplicate { onSave(duplicate) }
                }
            } message: {
                Text("You already saved this branch. Use it if it is the same place, or enter a clearer branch name.")
            }
        }
    }

    private var store: StoreLocation? {
        if case .edit(let store) = mode { return store }
        return nil
    }

    private var storeDisplayName: String {
        [name, branch].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " · ")
    }

    private func load() {
        guard let store else { return }
        name = store.name
        branch = store.branch
        city = store.city
        note = store.note
    }

    private func save() {
        let cleanedName = name.trimmingCharacters(in: .whitespaces)
        let cleanedBranch = branch.trimmingCharacters(in: .whitespaces)
        guard !cleanedName.isEmpty, !cleanedBranch.isEmpty else {
            showValidation = true
            return
        }

        if let store {
            store.name = cleanedName
            store.branch = cleanedBranch
            store.city = city.trimmingCharacters(in: .whitespaces)
            store.note = note.trimmingCharacters(in: .whitespaces)
            onSave(store)
            return
        }

        if let existing = stores.first(where: {
            !$0.isArchived
                && $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame
                && $0.branch.caseInsensitiveCompare(cleanedBranch) == .orderedSame
        }) {
            duplicate = existing
            showDuplicateAlert = true
            return
        }

        let store = StoreLocation(
            name: cleanedName,
            branch: cleanedBranch,
            city: "",
            note: ""
        )
        onSave(store)
    }
}
