import SwiftUI

struct CurrencyPickerView: View {
    @Binding var draft: ObservationDraft
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selection = "AMD"

    private var options: [CurrencyOption] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return CurrencyOption.all }
        return CurrencyOption.all.filter { $0.code.lowercased().contains(query) || $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack { formScreen }
    }

    private var formScreen: some View {
        ScreenScaffold(
            title: "Currency",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: "Use \(selection)") {
                    draft.currencyCode = selection
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Search currencies", text: $search)
                    .font(AppFont.inter(16))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10).stroke(Theme.separator)
                    }
                    .autocorrectionDisabled()

                VStack(spacing: 0) {
                    ForEach(options) { option in
                        SelectionRow(
                            title: option.title,
                            subtitle: option.code == "AMD" ? "Suggested from device region" : "Save an amount in \(option.code)",
                            isSelected: selection == option.code
                        ) {
                            selection = option.code
                        }
                        if option.id != options.last?.id { SeparatorLine() }
                    }
                }

                InfoText(text: "Selecting a currency does not convert the amount. Different currencies have separate comparisons and charts.")
            }
            .onAppear { selection = draft.currencyCode }
        }
    }
}

struct PriceBasisView: View {
    @Binding var draft: ObservationDraft
    @Environment(\.dismiss) private var dismiss

    @State private var isLoose = false
    @State private var sizeKnown = true
    @State private var quantityText = "1"
    @State private var unit: MeasurementUnit = .kilogram

    private var quantity: Decimal? { Format.decimal(from: quantityText) }
    private var currentPrice: Decimal? { draft.price }

    private var previewUnitPrice: Decimal? {
        guard let currentPrice, let quantity, quantity > 0, sizeKnown else { return nil }
        let base = quantity * unit.baseMultiplier
        guard base > 0 else { return nil }
        let total = Format.roundedForCurrency(currentPrice, currency: draft.currencyCode)
        let effective = draft.condition == .multiBuy ? total / Decimal(max(2, draft.multiBuyMinimum)) : total
        return effective / base
    }

    private var footerTitle: String {
        if !sizeKnown { return "Save package price only" }
        if isLoose { return "Save price per \(unit.symbol)" }
        return "Use \(Format.quantity(quantity ?? 0)) \(unit.symbol) package"
    }

    var body: some View {
        NavigationStack { formScreen }
    }

    private var formScreen: some View {
        ScreenScaffold(
            title: "Price basis",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: footerTitle) {
                    draft.isLoose = isLoose
                    draft.sizeKnown = sizeKnown
                    draft.quantityText = quantityText
                    draft.unit = unit
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                WrappingHStack {
                    FilterChip(title: "Package", isSelected: !isLoose && sizeKnown) {
                        isLoose = false
                        sizeKnown = true
                    }
                    FilterChip(title: "Per unit", isSelected: isLoose && sizeKnown) {
                        isLoose = true
                        sizeKnown = true
                    }
                }

                if sizeKnown {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Package amount *")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                        AdaptiveControlRow {
                            OutlinedField(placeholder: "900", text: $quantityText, keyboard: .decimalPad)
                            Menu {
                                ForEach(MeasurementUnit.allCases) { option in
                                    Button(option.symbol) { unit = option }
                                }
                            } label: {
                                HStack {
                                    Text(unit.symbol)
                                        .font(AppFont.inter(16))
                                        .foregroundStyle(Theme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(minWidth: 108, minHeight: 48)
                                .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                                .contentShape(Rectangle())
                            }
                        }
                    }

                    if let previewUnitPrice {
                        Text("At \(Format.money(currentPrice ?? 0, currency: draft.currencyCode)) \(draft.currencyCode) \(isLoose ? "for" : "per package")\n\(Format.number(previewUnitPrice, maxFraction: 2)) \(draft.currencyCode) / \(unit.baseUnitSymbol)")
                            .font(AppFont.inter(15, .medium))
                            .foregroundStyle(Theme.primaryText)
                            .lineSpacing(4)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Package size · Unknown")
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Text("No unit price will be calculated")
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                InfoText(text: isLoose
                    ? "Loose goods are priced for the weighed amount. Compatible weights and volumes convert; weight, volume and item count stay separate."
                    : "If you do not know the size, save the package price only. Unit comparison will be unavailable.")

                if sizeKnown {
                    Button("Package size unknown") {
                        sizeKnown = false
                    }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                } else {
                    Button("Enter a package size") {
                        sizeKnown = true
                    }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
            .onAppear {
                isLoose = draft.isLoose
                sizeKnown = draft.sizeKnown
                quantityText = draft.quantityText
                unit = draft.unit
            }
        }
    }
}

struct ConditionsView: View {
    @Binding var draft: ObservationDraft
    @Environment(\.dismiss) private var dismiss

    @State private var condition: ObservationCondition = .regular
    @State private var cardLabel = ""
    @State private var hasEndDate = false
    @State private var endDate = Date.now
    @State private var minimumPackages = "2"
    @State private var totalText = ""

    private var minimum: Int {
        max(2, Int(minimumPackages) ?? 2)
    }

    private var totalPrice: Decimal? { Format.decimal(from: totalText) }

    private var eachPackage: Decimal? {
        guard let totalPrice else { return nil }
        return totalPrice / Decimal(minimum)
    }

    private var unitPrice: Decimal? {
        guard let eachPackage, draft.sizeKnown, let quantity = draft.quantity, quantity > 0 else { return nil }
        let base = quantity * draft.unit.baseMultiplier
        guard base > 0 else { return nil }
        return eachPackage / base
    }

    private var footerTitle: String {
        switch condition {
        case .regular: "Use regular price"
        case .card: "Use this condition"
        case .multiBuy: "Save multi-buy observation"
        }
    }

    var body: some View {
        NavigationStack { formScreen }
    }

    private var formScreen: some View {
        ScreenScaffold(
            title: "Offer conditions",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: footerTitle) { apply() }
            }
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Text("When is this price available?")
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.primaryText)

                WrappingHStack {
                    ForEach(ObservationCondition.allCases) { option in
                        FilterChip(title: option.shortTitle, isSelected: condition == option) {
                            condition = option
                        }
                    }
                }

                if condition == .card {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Loyalty card / condition")
                        OutlinedField(placeholder: "SAS Club card required", text: $cardLabel)
                    }
                    Toggle(isOn: $hasEndDate) {
                        Text("Offer ends (optional)")
                            .font(AppFont.inter(15))
                            .foregroundStyle(Theme.primaryText)
                    }
                    .tint(Theme.accent)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, displayedComponents: .date)
                            .font(AppFont.inter(15))
                            .tint(Theme.accent)
                    }
                    InfoText(text: "This price will be labeled “Card required”. It will not replace the regular-price comparison.")
                } else if condition == .multiBuy {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Minimum packages required *")
                        OutlinedField(placeholder: "3", text: $minimumPackages, keyboard: .numberPad)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Total price for all packages *")
                        AdaptiveControlRow {
                            OutlinedField(placeholder: "900", text: $totalText, keyboard: .decimalPad)
                            Text(draft.currencyCode)
                                .font(AppFont.inter(16))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    if let eachPackage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(minimum) × \(draft.packageSummary.lowercased()) · \(Format.money(eachPackage, currency: draft.currencyCode)) \(draft.currencyCode) / package")
                            if let unitPrice {
                                Text("\(Format.number(unitPrice, maxFraction: 2)) \(draft.currencyCode) / \(draft.unit.baseUnitSymbol)")
                            }
                        }
                        .font(AppFont.inter(15, .medium))
                        .foregroundStyle(Theme.primaryText)
                    }
                    InfoText(text: "Must buy \(minimum) packages. Total outlay: \(totalPrice.map { Format.money($0, currency: draft.currencyCode) } ?? "0") \(draft.currencyCode). This total replaces the package price in the entry form.")
                } else {
                    InfoText(text: "Regular shelf or paid prices are compared with other regular prices at the same branch. Card and multi-buy offers stay in their own comparisons.")
                }
            }
            .onAppear {
                condition = draft.condition
                cardLabel = draft.conditionLabel
                if let date = draft.conditionEndDate {
                    hasEndDate = true
                    endDate = date
                }
                if draft.multiBuyMinimum > 1 {
                    minimumPackages = String(draft.multiBuyMinimum)
                }
                if draft.condition == .multiBuy {
                    totalText = draft.priceText
                }
            }
        }
    }

    private func apply() {
        draft.condition = condition
        switch condition {
        case .regular:
            draft.conditionLabel = ""
            draft.conditionEndDate = nil
            draft.multiBuyMinimum = 1
        case .card:
            draft.conditionLabel = cardLabel.isEmpty ? "Card required" : cardLabel
            draft.conditionEndDate = hasEndDate ? endDate : nil
            draft.multiBuyMinimum = 1
        case .multiBuy:
            draft.conditionLabel = ""
            draft.conditionEndDate = nil
            draft.multiBuyMinimum = minimum
            if totalText.isEmpty == false {
                draft.priceText = totalText
            }
        }
        dismiss()
    }
}

struct DateSourceView: View {
    @Binding var draft: ObservationDraft
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var source: ObservationSource = .shelf

    var body: some View {
        NavigationStack { formScreen }
    }

    private var formScreen: some View {
        ScreenScaffold(
            title: "Date & source",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: "Use date & source") {
                    draft.observedAt = date
                    draft.source = source
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Observation date")
                    DatePicker("", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Theme.accent)
                        .environment(\.locale, L10n.locale)
                    Text(Format.relativeThenDate(date))
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "How did you get this price?")
                    ForEach(ObservationSource.allCases) { option in
                        SelectionRow(title: option.title, isSelected: source == option) {
                            source = option
                        }
                    }
                }

                InfoText(text: "You can enter an earlier observation. Comparisons follow observation dates, not the day you typed it. Future dates are not accepted.")
            }
            .onAppear {
                date = min(draft.observedAt, Date.now)
                source = draft.source
            }
        }
    }
}


struct DiscardDraftView: View {
    let onKeepEditing: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        ScreenScaffold(
            title: "Discard changes?",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: onKeepEditing,
            footer: {
                VStack(spacing: 0) {
                    PrimaryButton(title: "Keep editing", action: onKeepEditing)
                    SecondaryButton(title: "Discard draft", color: Theme.error, action: onDiscard)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("You have unsaved changes")
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                InfoText(text: "Keep editing to finish your entry, or discard this draft.")
                InfoText(text: "Your saved history is kept. You will return to the product.")
            }
        }
    }
}
