import SwiftUI
import SwiftData

struct StoresView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
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
        ScreenScaffold(
            title: "Stores",
            backLabel: "Journal",
            topPadding: 8,
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
                            .frame(height: 48)
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                            .autocorrectionDisabled()
                    }

                    VStack(spacing: 0) {
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
                context.insert(store)
                try? context.save()
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

    @State private var showEdit = false

    private var products: [Product] {
        store.sortedProducts.filter { !$0.isArchived }
    }

    var body: some View {
        ScreenScaffold(
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
                    VStack(spacing: 0) {
                        ForEach(products) { product in
                            Button {
                                router.push(.productFromStore(product))
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .font(AppFont.inter(16, .medium))
                                            .foregroundStyle(Theme.primaryText)
                                        if let latest = PriceMath.latestObservation(for: product, store: store, condition: .regular) {
                                            Text("\(latest.unitPrice.map { Format.number($0, maxFraction: 2) } ?? Format.money(latest.price, currency: latest.currencyCode)) \(latest.currencyCode) / \(latest.baseUnitSymbol ?? "package") · \(Format.date(latest.observedAt))")
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
                archived.isArchived = true
                archived.archivedAt = .now
                try? context.save()
                showEdit = false
                dismiss()
            }
        }
    }
}

struct ArchivedStoresView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \StoreLocation.createdAt) private var stores: [StoreLocation]

    @State private var search = ""

    private var archived: [StoreLocation] {
        let base = stores.filter(\.isArchived)
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter { $0.displayName.lowercased().contains(query) || $0.city.lowercased().contains(query) }
    }

    var body: some View {
        ScreenScaffold(
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
                    .frame(height: 48)
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                    .autocorrectionDisabled()

                if archived.isEmpty {
                    InfoText(text: "No archived stores.")
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 0) {
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
                                    try? context.save()
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Product.createdAt) private var products: [Product]

    @State private var search = ""

    private var archived: [Product] {
        let base = products.filter(\.isArchived)
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter { $0.searchText.contains(query) }
    }

    var body: some View {
        ScreenScaffold(
            title: "Archived products",
            backLabel: "Settings",
            footer: {
                SecondaryButton(title: "Back to Journal") {
                    dismiss()
                    router.reset()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                FieldLabel(text: "Find an archived product")
                TextField("Search products", text: $search)
                    .font(AppFont.inter(16))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                    .autocorrectionDisabled()

                if archived.isEmpty {
                    InfoText(text: "No archived products.")
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(archived) { product in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(product.displayName)
                                    .font(AppFont.inter(16, .medium))
                                    .foregroundStyle(Theme.primaryText)
                                Text("\(product.observations.count) observations · Archived \(product.archivedAt.map { Format.relativeAge($0).lowercased() } ?? "")\nHistory is kept")
                                    .font(AppFont.inter(14))
                                    .foregroundStyle(Theme.secondaryText)
                                Button("Restore \(product.name)") {
                                    product.isArchived = false
                                    product.archivedAt = nil
                                    try? context.save()
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

                InfoText(text: "Restored products return to the Journal with all their earlier prices.")
                    .padding(.top, 12)
            }
        }
    }
}
