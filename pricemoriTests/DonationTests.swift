import StoreKitTest
import Testing
@testable import pricemori

@MainActor
struct DonationTests {
    @Test func catalogLoadsAllTiers() async throws {
        let session = try SKTestSession(configurationFileNamed: "Pricemori")
        session.disableDialogs = true
        session.clearTransactions()

        let store = DonationStore()
        await store.loadProducts(force: true)
        #expect(store.products.count == 6)
        #expect(store.products.first?.displayPrice == "$2.99")
        #expect(store.products.contains { $0.id == "com.mrmaier.pricemori.tip.extraordinary" })

        session.clearTransactions()
    }

    @Test func purchaseCompletesAsThankYou() async throws {
        let session = try SKTestSession(configurationFileNamed: "Pricemori")
        session.disableDialogs = true
        session.clearTransactions()

        let store = DonationStore()
        await store.loadProducts(force: true)
        let product = try #require(store.product(for: DonationTier.all[0]))

        await store.purchase(product)

        #expect(store.feedback == .thankYou)
        #expect(store.purchasingProductID == nil)

        session.clearTransactions()
    }
}
