import SwiftUI
import SwiftData

struct RootView: View {
    @Query(sort: \Product.createdAt) private var products: [Product]
    @Query private var stores: [StoreLocation]
    @StateObject private var router = AppRouter()
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @AppStorage(Onboarding.storageKey) private var hasCompletedOnboarding = false

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                journal
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .environmentObject(router)
        .environment(\.locale, appLanguage.locale)
        .tint(Theme.accent)
        .background(Theme.background)
    }

    private var journal: some View {
        NavigationStack(path: $router.path) {
            Group {
                if products.isEmpty && stores.isEmpty {
                    WelcomeView()
                } else {
                    JournalView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .fullScreenCover(isPresented: $router.showFirstProduct, onDismiss: {
            if let product = router.pendingFirstProduct {
                router.pendingFirstProduct = nil
                router.push(product.observations.isEmpty ? .product(product) : .productFirstSave(product))
            }
        }) {
            AddProductFlow(mode: .onboarding) { product in
                router.pendingFirstProduct = product
                router.showFirstProduct = false
            }
        }
        .fullScreenCover(isPresented: $router.showInitialRestore) { RestoreBackupSheet() }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .product(let product):
            ProductDetailView(product: product)
        case .productFirstSave(let product):
            ProductDetailView(product: product, isFirstSave: true)
        case .productAfterRecording(let product, let observationID):
            ProductDetailView(product: product, savedObservation: product.observations.first { $0.id == observationID })
        case .productFromSearch(let product):
            ProductDetailView(product: product, backLabel: "Search")
        case .productFromArchive(let product):
            ProductDetailView(product: product, backLabel: "Archive")
        case .productFromJournalBranch(let product, let store):
            ProductDetailView(product: product, initialStore: store)
        case .productFromStore(let product, let store):
            ProductDetailView(product: product, backLabel: "Store", initialStore: store)
        case .search:
            SearchView()
        case .favorites:
            FavoritesView()
        case .history(let product, let store, let condition):
            HistoryView(product: product, store: store, condition: condition, backLabel: "Back")
        case .allHistory(let product):
            ProductHistoryView(product: product)
        case .scopedPriceOverTime(let product, let store, let referenceID):
            PriceOverTimeView(product: product, initialStore: store, initialCondition: product.observations.first { $0.id == referenceID }?.condition ?? .regular, initialReferenceID: referenceID)
        case .scopedHistory(let product, let store, let condition, let currency, let referenceID):
            HistoryView(product: product, store: store, condition: condition, backLabel: "Back", referenceID: referenceID, currencyFilter: currency)
        case .conditionalOffers(let product):
            ConditionalOffersView(product: product)
        case .packageVsUnit(let product, let store):
            PackageVsUnitView(product: product, store: store)
        case .statistics(let product, let store):
            StatisticsView(preferredProduct: product, preferredStore: store)
        case .priceOverTime(let product, let store, let condition):
            PriceOverTimeView(product: product, initialStore: store, initialCondition: condition)
        case .compareStores(let product):
            CompareStoresView(product: product)
        case .storeHistories(let product):
            StoreHistoriesView(product: product)
        case .moreComparisons(let product, let store):
            MoreComparisonsView(product: product, store: store)
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
