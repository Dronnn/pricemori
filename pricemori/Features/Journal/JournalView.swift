import SwiftUI
import SwiftData

struct JournalView: View {
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \Product.createdAt) private var allProducts: [Product]
    @Query(sort: \StoreLocation.createdAt) private var allStores: [StoreLocation]

    @State private var favoritesOnly = false
    @State private var storeFilter: StoreLocation?
    @State private var sort: JournalSort = .recent
    @State private var showFilters = false
    @State private var showMenu = false
    @State private var showAdd = false
    @State private var showDonation = false
    @State private var pendingProduct: Product?
    @State private var pendingFirstSave = false

    private var activeProducts: [Product] {
        allProducts.filter { !$0.isArchived }
    }

    private var entries: [JournalEntry] {
        var products = activeProducts
        if favoritesOnly { products = products.filter(\.isFavorite) }
        if let storeFilter {
            products = products.filter { product in
                product.observations.contains { $0.store?.id == storeFilter.id }
            }
        }

        var result = products.map { product in
            JournalEntry(
                product: product,
                observation: storeFilter.flatMap {
                    let branch = $0
                    return product.observations.filter { $0.store?.id == branch.id }
                        .max { PriceMath.isEarlier($0, than: $1) }
                } ?? (storeFilter == nil ? product.latestObservation : nil)
            )
        }

        switch sort {
        case .recent:
            result.sort { lhs, rhs in
                let left = lhs.observation?.observedAt ?? lhs.product.createdAt
                let right = rhs.observation?.observedAt ?? rhs.product.createdAt
                if left == right {
                    return lhs.product.name.localizedCaseInsensitiveCompare(rhs.product.name) == .orderedAscending
                }
                return left > right
            }
        case .name:
            result.sort { $0.product.name.localizedCaseInsensitiveCompare($1.product.name) == .orderedAscending }
        }
        return result
    }

    var body: some View {
        ScreenScaffold(
            title: "Journal",
            backLabel: "Menu",
            showsBackChevron: false,
            backAction: { showMenu = true },
            topPadding: 16,
            scrollsContent: false,
            trailing: {
                HStack(spacing: 2) {
                    Button {
                        showDonation = true
                    } label: {
                        Image(systemName: "heart")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(Theme.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Support Pricemori")

                    HeaderActionButton(title: "+ Add") { showAdd = true }
                }
            }
        ) {
            List {
                Group {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search products")
                                .font(AppFont.inter(13))
                                .foregroundStyle(Theme.secondaryText)
                            SearchFieldButton(placeholder: "Search name, brand or model") {
                                router.push(.search)
                            }
                        }
                        WrappingHStack {
                            FilterChip(title: "All", isSelected: !favoritesOnly) {
                                favoritesOnly = false
                            }
                            FilterChip(title: "Favorites", isSelected: false) {
                                router.push(.favorites)
                            }
                            FilterChip(title: "Filter / sort", isSelected: storeFilter != nil) {
                                showFilters = true
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .listRowSeparator(.hidden)

                    if entries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string(activeProducts.isEmpty ? "No active products" : favoritesOnly ? "No favorite products" : "No products match this filter"))
                                .font(AppFont.inter(16, .medium))
                                .foregroundStyle(Theme.primaryText)
                            Text(L10n.string(activeProducts.isEmpty
                                ? (allProducts.contains(where: \.isArchived) ? "Add a product or restore one from Archived products." : "Start with one product you buy regularly.")
                                : favoritesOnly ? "Mark a product as a favorite to find it quickly."
                                : "Choose another store or show all branches."))
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                            if allProducts.contains(where: \.isArchived) {
                                Button("Archived products") { router.push(.archivedProducts) }
                                    .frame(minHeight: 44)
                            }
                        }
                        .padding(.vertical, 24)
                    } else {
                        ForEach(entries) { entry in
                            NavigationLink(value: storeFilter.map { AppRoute.productFromJournalBranch(entry.product, $0) } ?? .product(entry.product)) {
                                    JournalProductRow(
                                        product: entry.product,
                                        observation: entry.observation
                                    )
                                }
                            .buttonStyle(.plain)
                            .modifier(ProductRowActions(product: entry.product, store: storeFilter))
                            .listRowSeparatorTint(Theme.separator)
                        }
                    }

                    Button {
                        router.push(.statistics(nil, nil))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Statistics & charts")
                                .font(AppFont.inter(17, .semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text("Price progression · Store bars · Period changes")
                                .font(AppFont.inter(14))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { SeparatorLine() }
                    .overlay(alignment: .bottom) { SeparatorLine() }
                    .padding(.top, 16)
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Theme.background)
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
        }
        .fullScreenCover(isPresented: $showMenu) {
            JournalMenuView { route in
                showMenu = false
                router.push(route)
            }
        }
        .fullScreenCover(isPresented: $showFilters) {
            JournalFiltersView(
                favoritesOnly: $favoritesOnly,
                storeFilter: $storeFilter,
                sort: $sort,
                stores: allStores.filter { !$0.isArchived }
            )
        }
        .fullScreenCover(isPresented: $showDonation) {
            DonationView()
        }
        .fullScreenCover(isPresented: $showAdd, onDismiss: {
            if let pendingProduct {
                self.pendingProduct = nil
                router.push(pendingFirstSave ? .productFirstSave(pendingProduct) : .product(pendingProduct))
                pendingFirstSave = false
            }
        }) {
            AddProductFlow(mode: .full) { product in
                pendingProduct = product
                pendingFirstSave = !product.observations.isEmpty
                showAdd = false
            }
        }
    }

}

private struct JournalEntry: Identifiable {
    let product: Product
    let observation: PriceObservation?

    var id: UUID { product.id }
}

struct JournalProductRow: View {
    let product: Product
    let observation: PriceObservation?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(AppFont.inter(16, .medium))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.leading)
                if let observation {
                    Text("\(observation.packagePriceLine) · \(observation.store?.name ?? ""), \(observation.store?.branch ?? "")")
                        .font(AppFont.inter(15))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                    Text(Format.dateAndAge(observation.observedAt))
                        .font(AppFont.inter(15))
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text("No prices yet · Add the first price")
                        .font(AppFont.inter(15))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}

struct JournalMenuView: View {
    let onSelect: (AppRoute) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenScaffold(
            title: "Journal menu",
            backLabel: "Close",
            showsBackChevron: false,
            backAction: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                MenuRow(
                    title: "Statistics & charts",
                    subtitle: "Explore progression, comparisons and changes"
                ) { onSelect(.statistics(nil, nil)) }
                SeparatorLine()
                MenuRow(
                    title: "Stores",
                    subtitle: "Your usual stores and individual branches"
                ) { onSelect(.stores) }
                SeparatorLine()
                MenuRow(
                    title: "Archived products",
                    subtitle: "View history or resume tracking"
                ) { onSelect(.archivedProducts) }
                SeparatorLine()
                MenuRow(
                    title: "Settings",
                    subtitle: "Entry defaults, archives and backup"
                ) { onSelect(.settings) }

                InfoText(text: "Recording, search and favorites are directly on Journal. This menu is for other sections.")
                    .padding(.top, 28)
            }
        }
    }
}

struct MenuRow: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(title))
                        .font(AppFont.inter(16, .medium))
                        .foregroundStyle(Theme.primaryText)
                    Text(L10n.string(subtitle))
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct JournalFiltersView: View {
    @Binding var favoritesOnly: Bool
    @Binding var storeFilter: StoreLocation?
    @Binding var sort: JournalSort
    let stores: [StoreLocation]

    @Environment(\.dismiss) private var dismiss
    @State private var localFavorites = false
    @State private var localStore: StoreLocation?
    @State private var localSort: JournalSort = .recent

    var body: some View {
        ScreenScaffold(
            title: "Journal filters",
            backLabel: "Cancel",
            showsBackChevron: false,
            backAction: { dismiss() },
            footer: {
                PrimaryButton(title: "Apply filters") {
                    favoritesOnly = localFavorites
                    storeFilter = localStore
                    sort = localSort
                    dismiss()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Products")
                    SelectionRow(title: "All active", isSelected: !localFavorites) { localFavorites = false }
                    SelectionRow(title: "Favorites", isSelected: localFavorites) { localFavorites = true }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Store location")
                    SelectionRow(
                        title: "All active branches",
                        subtitle: "Show products from any saved store",
                        isSelected: localStore == nil
                    ) { localStore = nil }
                    ForEach(stores) { store in
                        SelectionRow(
                            title: store.displayName,
                            subtitle: "Only products observed at this branch",
                            isSelected: localStore?.id == store.id
                        ) { localStore = store }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Sort by")
                    SelectionRow(title: "Recent", isSelected: localSort == .recent) { localSort = .recent }
                    SelectionRow(title: "Name", isSelected: localSort == .name) { localSort = .name }
                }
            }
            .onAppear {
                localFavorites = favoritesOnly
                localStore = storeFilter
                localSort = sort
            }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your price journal")
                .font(AppFont.serif(32))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 8)

            Text("Remember prices at your stores.")
                .font(AppFont.inter(15, .semibold))
                .foregroundStyle(Theme.primaryText)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                InfoText(text: "Record a shelf price or what you paid. Compare it with your own earlier observations.")
                InfoText(text: "Works offline. Your journal stays on this device. No account is needed.")
                    .padding(.top, 34)
            }
            .padding(.top, 18)

            VStack(spacing: 8) {
                PrimaryButton(title: "Add your first product") { router.showFirstProduct = true }
                SecondaryButton(title: "Restore a backup") { router.showInitialRestore = true }
            }
            .padding(.top, 200)

            InfoText(text: "Start with one product you buy regularly.")
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
