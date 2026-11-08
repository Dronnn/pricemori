import StoreKitTest
import Testing
@testable import pricemori

@MainActor
struct DonationTests {
    @Test func catalogLoadsAndPurchaseCompletes() async throws {
        let session = try SKTestSession(configurationFileNamed: "Pricemori")
        session.disableDialogs = true
        session.clearTransactions()

        let store = DonationStore()
        await store.loadProducts(force: true)
        #expect(store.products.count == 6)
        #expect(store.products.first?.displayPrice == "$2.99")
        #expect(store.products.contains { $0.id == "com.mrmaier.pricemori.tip.extraordinary" })

        #expect(store.products.contains { $0.id == "com.mrmaier.pricemori.tip.medium" })
        session.clearTransactions()
    }
}
