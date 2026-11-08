import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \Product.createdAt) private var products: [Product]
    @StateObject private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if products.isEmpty {
                    WelcomeView()
                } else {
                    JournalView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .environmentObject(router)
        .tint(Theme.accent)
        .background(Theme.background)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .product(let product):
            ProductDetailView(product: product)
        case .productFirstSave(let product):
            ProductDetailView(product: product, isFirstSave: true)
        case .productFromSearch(let product):
            ProductDetailView(product: product, backLabel: "Search")
        case .productFromStore(let product):
            ProductDetailView(product: product, backLabel: "Store")
        case .search:
            SearchView()
        case .favorites:
            FavoritesView()
        case .history(let product, let store, let condition):
            HistoryView(product: product, store: store, condition: condition, backLabel: "Back")
        case .conditionalOffers(let product):
            ConditionalOffersView(product: product)
        case .packageVsUnit(let product, let store):
            PackageVsUnitView(product: product, store: store)
        case .statistics(let product, let store):
            StatisticsView(preferredProduct: product, preferredStore: store)
        case .priceOverTime(let product, let store):
            PriceOverTimeView(product: product, initialStore: store)
        case .compareStores(let product):
            CompareStoresView(product: product)
        case .storeHistories(let product):
            StoreHistoriesView(product: product)
        case .moreComparisons(let product):
            MoreComparisonsView(product: product)
        case .periodChanges(let store):
            PeriodChangesView(store: store)
        case .stores:
            StoresView()
        case .store(let store):
            StoreDetailView(store: store)
        case .settings:
            SettingsView()
        case .support:
            DonationView(backLabel: "Settings")
        case .entryDefaults:
            EntryDefaultsView()
        case .backup:
            BackupExportView()
        case .archivedProducts:
            ArchivedProductsView()
        case .archivedStores:
            ArchivedStoresView()
        }
    }
}
