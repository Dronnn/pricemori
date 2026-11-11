import SwiftUI
import SwiftData

struct StoresView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var search = ""
    @State private var showAdd = false

    private var activeStores: [StoreLocation] {
        let base = stores.filter { !$0.isArchived }
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.displayName.lowercased().contains(query)
                || $0.city.lowercased().contains(query)
                || $0.note.lowercased().contains(query)
        }
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Stores",
            backLabel: "Journal",
            topPadding: 16,
            trailing: {
                HeaderActionButton(title: "+ Add") { showAdd = true }
            },
            footer: {
                VStack(spacing: 0) {
                    SecondaryButton(title: "Archived stores") {
                        router.push(.archivedStores)
                    }
                }
            }
        ) {
            if stores.filter({ !$0.isArchived }).isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Add your familiar stores")
                        .font(AppFont.serif(32))
                        .foregroundStyle(Theme.primaryText)
                    InfoText(text: "Keep each branch separate so your price comparisons refer to the right place.")
                    PrimaryButton(title: "Add a store location") { showAdd = true }
                    SecondaryButton(title: "View archived stores") {
                        router.push(.archivedStores)
                    }
                    InfoText(text: "You can also add a branch while recording your first price.")
                        .padding(.top, 8)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search locations")
                            .font(AppFont.inter(13))
                            .foregroundStyle(Theme.secondaryText)
                        TextField("Store name, branch or address", text: $search)
                            .font(AppFont.inter(16))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(minHeight: 48)
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                            .contentShape(Rectangle())
                            .autocorrectionDisabled()
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(activeStores) { store in
                            Button {
                                router.push(.store(store))
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(store.displayName)
                                            .font(AppFont.inter(16, .medium))
                                            .foregroundStyle(Theme.primaryText)
                                        Text("\(store.city) · \(store.productCount) \(store.productCount == 1 ? "product" : "products")")
                                            .font(AppFont.inter(14))
                                            .foregroundStyle(Theme.secondaryText)
                                        if let latest = store.latestObservation {
                                            Text("Last observation: \(Format.date(latest.observedAt))")
                                                .font(AppFont.inter(13))
                                                .foregroundStyle(Theme.secondaryText)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            SeparatorLine()
                        }
                    }

                    InfoText(text: "Locations are separate, even when the chain name is the same.")
                        .padding(.top, 8)
                }
            }
        }
        .fullScreenCover(isPresented: $showAdd) {
            StoreFormView(mode: .add) { store in
                showAdd = false
            }
        }
    }
}

struct StoreDetailView: View {
    let store: StoreLocation

    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveError = false

    @State private var showEdit = false

    private var products: [Product] {
        store.sortedProducts
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Store",
            backLabel: "Stores",
            trailing: {
                HeaderActionButton(title: "Edit") { showEdit = true }
            }
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.displayName)
                    .font(AppFont.serif(32))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !store.detailLine.isEmpty {
                    Text(store.detailLine)
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 6)
                }

                if products.isEmpty {
                    InfoText(text: "No products recorded at this branch yet.")
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(products) { product in
                            Button {
                                router.push(.productFromStore(product, store))
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .font(AppFont.inter(16, .medium))
                                            .foregroundStyle(Theme.primaryText)
                                        if product.isArchived {
                                            Text("Archived products").font(AppFont.inter(13)).foregroundStyle(Theme.secondaryText)
                                        }
                                        if let latest = PriceMath.latestObservation(for: product, store: store) {
                                            Text("\(latest.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.number(latest.effectivePackagePrice, maxFraction: 2)) \(latest.currencyCode) / \(latest.baseUnitSymbol ?? "package") · \(Format.date(latest.observedAt))")
                                                .font(AppFont.inter(14))
                                                .foregroundStyle(Theme.secondaryText)
                                            Text("\(latest.condition.shortTitle) · \(latest.source.title)")
                                                .font(AppFont.inter(13))
                                                .foregroundStyle(Theme.secondaryText)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            SeparatorLine()
                        }
                    }
                    .padding(.top, 16)
                }

                SecondaryButton(title: "Price changes at this store") {
                    router.push(.periodChanges(store))
                }
                .padding(.top, 18)

                InfoText(text: "Choose a product to record a new price. Each row shows its latest observation at this branch.")
                    .padding(.top, 12)
            }
        }
        .fullScreenCover(isPresented: $showEdit) {
            StoreFormView(mode: .edit(store)) { _ in
                showEdit = false
            } onArchive: { archived in
                showEdit = false
                dismiss()
            }
        }
    }
}

struct ArchivedStoresView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var search = ""

    private var archived: [StoreLocation] {
        let base = stores.filter(\.isArchived)
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter { $0.displayName.lowercased().contains(query) || $0.city.lowercased().contains(query) }
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError,
            title: "Archived stores",
            backLabel: "Stores",
            footer: {
                SecondaryButton(title: "Back to active stores") { dismiss() }
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                FieldLabel(text: "Find a location")
                TextField("Search archived stores", text: $search)
                    .font(AppFont.inter(16))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                    .contentShape(Rectangle())
                    .autocorrectionDisabled()

                if archived.isEmpty {
                    InfoText(text: "No archived stores.")
                        .padding(.top, 20)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(archived) { store in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(store.displayName)
                                    .font(AppFont.inter(16, .medium))
                                    .foregroundStyle(Theme.primaryText)
                                Text("\(store.city) · \(store.observations.count) observations kept\nArchived \(store.archivedAt.map { Format.relativeAge($0).lowercased() } ?? "")")
                                    .font(AppFont.inter(14))
                                    .foregroundStyle(Theme.secondaryText)
                                Button("Restore this location") {
                                    store.isArchived = false
                                    store.archivedAt = nil
                                    guard context.saveReportingError(&saveError) else { return }
                                }
                                .font(AppFont.inter(15, .medium))
                                .foregroundStyle(Theme.secondaryText)
                                .buttonStyle(.plain)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                            SeparatorLine()
                        }
                    }
                }

                InfoText(text: "Restoring makes the branch available for new prices and regular comparisons again.")
                    .padding(.top, 12)
            }
        }
    }
}

struct ArchivedProductsView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @Query(sort: \Product.createdAt) private var products: [Product]
    @State private var search = ""
    @State private var restoredName: String?
    @State private var deletingProduct: Product?

    private var allArchived: [Product] { products.filter(\.isArchived) }
    private var archived: [Product] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allArchived.filter { query.isEmpty || $0.searchText.contains(query) }
            .sorted { ($0.archivedAt ?? $0.createdAt) > ($1.archivedAt ?? $1.createdAt) }
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError, title: "Archived products", backLabel: "Back", scrollsContent: false,
            footer: { SecondaryButton(title: "Back to Journal") { router.reset() } }
        ) {
            List {
                Group {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoText(text: "Archived products are hidden from Journal. Their history is kept.")
                        TextField("Search products", text: $search)
                            .font(AppFont.inter(16))
                            .padding(14)
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                            .contentShape(Rectangle())
                            .autocorrectionDisabled()
                        if let restoredName {
                            Text(L10n.format("%@ restored to Journal.", restoredName))
                                .font(AppFont.inter(14)).foregroundStyle(Theme.accent)
                                .accessibilityIdentifier("archive-restore-confirmation")
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .listRowSeparator(.hidden)

                    if archived.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string(allArchived.isEmpty ? "No archived products." : "No matching products"))
                                .font(AppFont.inter(17, .medium))
                            InfoText(text: allArchived.isEmpty
                                ? "Restored products return to the Journal with all their earlier prices."
                                : "Search name, brand or model")
                        }
                        .padding(.vertical, 20)
                        .listRowSeparator(.hidden)
                    }
                    ForEach(archived) { product in
                        VStack(alignment: .leading, spacing: 8) {
                            Button { router.push(.productFromArchive(product)) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(product.displayName).font(AppFont.inter(17, .medium))
                                        Text("\(product.observations.count) observations · Archived \(product.archivedAt.map { Format.relativeAge($0).lowercased() } ?? "")\nHistory is kept")
                                            .font(AppFont.inter(14)).foregroundStyle(Theme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption)
                                }
                                .foregroundStyle(Theme.primaryText)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Button("Restore \(product.name)") { restore(product) }
                                .font(AppFont.inter(15, .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                                .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { restore(product) } label: { Label("Restore product", systemImage: "arrow.uturn.backward") }
                                .tint(Theme.accent)
                        }
                        .contextMenu {
                            Button("History") { router.push(.allHistory(product)) }
                            Button("Restore product") { restore(product) }
                            Button("Delete product…", role: .destructive) { deletingProduct = product }
                        }
                    }
                }
                .listRowBackground(Theme.background)
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .alert("Delete product permanently?", isPresented: Binding(
            get: { deletingProduct != nil }, set: { if !$0 { deletingProduct = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingProduct = nil }
            Button("Delete product", role: .destructive) {
                guard let product = deletingProduct else { return }
                deletingProduct = nil
                context.delete(product)
                _ = context.saveReportingError(&saveError)
            }
        } message: {
            Text(L10n.format("Delete %@ and all %lld recorded prices? This cannot be undone.", deletingProduct?.name ?? "", deletingProduct?.observations.count ?? 0))
        }
    }

    private func restore(_ product: Product) {
        let name = product.name
        product.isArchived = false
        product.archivedAt = nil
        guard context.saveReportingError(&saveError) else { return }
        restoredName = name
    }
}
