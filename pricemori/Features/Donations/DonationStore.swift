import Combine
import Foundation
import StoreKit

enum DonationFeedback: Equatable {
    case thankYou
    case pending
    case failed
}

struct DonationTier: Identifiable, Equatable {
    let id: String
    let name: String
    let fallbackPrice: String

    static let all: [DonationTier] = [
        DonationTier(id: "com.mrmaier.pricemori.tip.small", name: "Small tip", fallbackPrice: "$2.99"),
        DonationTier(id: "com.mrmaier.pricemori.tip.medium", name: "Medium tip", fallbackPrice: "$4.99"),
        DonationTier(id: "com.mrmaier.pricemori.tip.large", name: "Large tip", fallbackPrice: "$7.99"),
        DonationTier(id: "com.mrmaier.pricemori.tip.generous", name: "Generous tip", fallbackPrice: "$19.99"),
        DonationTier(id: "com.mrmaier.pricemori.tip.patron", name: "Patron tip", fallbackPrice: "$49.99"),
        DonationTier(id: "com.mrmaier.pricemori.tip.extraordinary", name: "Extraordinary tip", fallbackPrice: "$99.99")
    ]
}

@MainActor
final class DonationStore: ObservableObject {
    static let shared = DonationStore()
    static let productIDs = DonationTier.all.map(\.id)

    @Published private(set) var products: [StoreKit.Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var feedback: DonationFeedback?
    @Published private(set) var purchasingProductID: String?

    private var updatesTask: Task<Void, Never>?
    private var handledTransactionIDs: Set<UInt64> = []

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.process(result, showFeedback: true)
            }
        }
        Task { [weak self] in
            await self?.processUnfinishedTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func product(for tier: DonationTier) -> StoreKit.Product? {
        products.first { $0.id == tier.id }
    }

    func displayPrice(for tier: DonationTier) -> String {
        product(for: tier)?.displayPrice ?? tier.fallbackPrice
    }

    func displayName(for tier: DonationTier) -> String {
        product(for: tier)?.displayName ?? tier.name
    }

    func loadProducts(force: Bool = false) async {
        guard force || products.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await StoreKit.Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                errorMessage = "Donations are unavailable right now."
            }
        } catch {
            products = []
            errorMessage = "The App Store is unavailable. Check your connection and try again."
        }
    }

    func purchase(_ product: StoreKit.Product) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        feedback = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification,
                      transaction.productID == product.id
                else {
                    feedback = .failed
                    return
                }
                handledTransactionIDs.insert(transaction.id)
                feedback = .thankYou
                await transaction.finish()
            case .pending:
                feedback = .pending
            case .userCancelled:
                break
            @unknown default:
                feedback = .failed
            }
        } catch is CancellationError {
            return
        } catch {
            if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError {
                return
            }
            feedback = .failed
        }
    }

    func clearFeedback() {
        feedback = nil
    }

    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard !Task.isCancelled else { break }
            await process(result, showFeedback: false)
        }
    }

    private func process(_ result: VerificationResult<Transaction>, showFeedback: Bool) async {
        guard case .verified(let transaction) = result,
              Self.productIDs.contains(transaction.productID),
              transaction.productType == .consumable
        else { return }

        if showFeedback,
           transaction.revocationDate == nil,
           handledTransactionIDs.insert(transaction.id).inserted {
            feedback = .thankYou
        }
        await transaction.finish()
    }
}
