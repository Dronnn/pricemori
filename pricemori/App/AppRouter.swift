import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var showFirstProduct = false
    @Published var showInitialRestore = false
    var pendingFirstProduct: Product?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func reset() {
        path = NavigationPath()
    }
}

enum AppRoute: Hashable {
    case product(Product)
    case productFirstSave(Product)
    case productAfterRecording(Product, UUID)
    case productFromSearch(Product)
    case productFromArchive(Product)
    case productFromStore(Product, StoreLocation)
    case productFromJournalBranch(Product, StoreLocation)
    case search
    case favorites
    case history(Product, StoreLocation?, ObservationCondition)
    case allHistory(Product)
    case scopedHistory(Product, StoreLocation, ObservationCondition, String, UUID)
    case scopedPriceOverTime(Product, StoreLocation, UUID)
    case conditionalOffers(Product)
    case packageVsUnit(Product, StoreLocation?)
    case statistics(Product?, StoreLocation?)
    case priceOverTime(Product, StoreLocation, ObservationCondition)
    case compareStores(Product)
    case storeHistories(Product)
    case moreComparisons(Product, StoreLocation?)
    case periodChanges(StoreLocation?)
    case stores
    case store(StoreLocation)
    case settings
    case support
    case entryDefaults
    case backup
    case archivedProducts
    case archivedStores
}
