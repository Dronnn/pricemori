import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

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
    case productFromSearch(Product)
    case productFromStore(Product)
    case search
    case favorites
    case history(Product, StoreLocation?, ObservationCondition)
    case conditionalOffers(Product)
    case packageVsUnit(Product, StoreLocation?)
    case statistics(Product?, StoreLocation?)
    case priceOverTime(Product, StoreLocation)
    case compareStores(Product)
    case storeHistories(Product)
    case moreComparisons(Product)
    case periodChanges(StoreLocation?)
    case stores
    case store(StoreLocation)
    case settings
    case entryDefaults
    case backup
    case archivedProducts
    case archivedStores
}
