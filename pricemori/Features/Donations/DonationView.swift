import StoreKit
import SwiftUI

struct DonationView: View {
    var backLabel: String = "Close"

    @ObservedObject private var store = DonationStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTierID = DonationTier.all[1].id
    @State private var didRequestProducts = false

    private var selectedTier: DonationTier {
        DonationTier.all.first { $0.id == selectedTierID } ?? DonationTier.all[1]
    }

    private var selectedProduct: StoreKit.Product? {
        store.product(for: selectedTier)
    }

    var body: some View {
        ScreenScaffold(
            title: "Support Pricemori",
            backLabel: backLabel,
            showsBackChevron: false,
            backAction: {
                store.clearFeedback()
                dismiss()
            },
            footer: {
                if store.feedback == .thankYou {
                    PrimaryButton(title: "Done") {
                        store.clearFeedback()
                        dismiss()
                    }
                } else {
                    PrimaryButton(
                        title: L10n.format("Donate %@", store.displayPrice(for: selectedTier)),
                        isEnabled: selectedProduct != nil && store.purchasingProductID == nil
                    ) {
                        guard let selectedProduct else { return }
                        Task { await store.purchase(selectedProduct) }
                    }
                }
            }
        ) {
            if store.feedback == .thankYou {
                thankYouContent
            } else {
                donationContent
            }
        }
        .task {
            guard !didRequestProducts else { return }
            didRequestProducts = true
            await store.loadProducts()
        }
    }

    private var donationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Keep Pricemori\nindependent.")
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            InfoText(text: "Pricemori is designed, built, and maintained by one developer. If it helps you, a tip is appreciated. Everything stays available either way.")

            FieldLabel(text: "Choose an amount")
                .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(DonationTier.all) { tier in
                    DonationTierButton(
                        name: store.displayName(for: tier),
                        price: store.displayPrice(for: tier),
                        isSelected: selectedTierID == tier.id
                    ) {
                        selectedTierID = tier.id
                    }
                }
            }

            if store.isLoading && store.products.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading App Store prices…")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                }
            } else if let errorMessage = store.errorMessage, store.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                    Button("Try again") {
                        Task { await store.loadProducts(force: true) }
                    }
                    .font(AppFont.inter(15, .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }

            switch store.feedback {
            case .pending:
                InfoText(text: "Your donation is awaiting approval.")
            case .failed:
                Text("The donation could not be completed. Please try again.")
                    .font(AppFont.inter(14))
                    .foregroundStyle(Theme.error)
            default:
                EmptyView()
            }

            InfoText(text: "Prices are set by the App Store for your country and charged to your Apple Account. Donations are optional, consumable tips. They do not unlock features.")
                .padding(.top, 4)
        }
    }

    private var thankYouContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(height: 44)

            Text("Thank you.")
                .font(AppFont.serif(36))
                .foregroundStyle(Theme.primaryText)

            InfoText(text: "Your support helps keep Pricemori independent. Nothing is unlocked, and your journal stays exactly as it is.")
        }
    }
}

private struct DonationTierButton: View {
    let name: String
    let price: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(AppFont.inter(13, .medium))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(price)
                    .font(AppFont.inter(22, .semibold))
                    .foregroundStyle(Theme.primaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.09) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Theme.accent : Theme.separator, lineWidth: isSelected ? 1.5 : 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
