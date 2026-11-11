import SwiftUI
import SwiftData

struct SearchView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Product.createdAt) private var products: [Product]

    @State private var query = ""
    @State private var showAdd = false
    @State private var pendingProduct: Product?
    @FocusState private var focused: Bool

    private var matches: [Product] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return [] }
        return products.filter { !$0.isArchived && $0.searchText.contains(cleaned) }
    }

    var body: some View {
        ScreenScaffold(title: "Search", backLabel: "Journal") {
            VStack(alignment: .leading, spacing: 16) {
                FieldLabel(text: "Products")
                TextField("Search name, brand or model", text: $query)
                    .font(AppFont.inter(16))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .overlay { RoundedRectangle(cornerRadius: 10).stroke(Theme.separator) }
                    .contentShape(Rectangle())
                    .autocorrectionDisabled()
                    .focused($focused)

                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(matches.isEmpty ? "No matching products" : "\(matches.count) matching \(matches.count == 1 ? "product" : "products")")
                        .font(AppFont.inter(14))
                        .foregroundStyle(Theme.secondaryText)
                }

                if matches.isEmpty && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        InfoText(text: "Try a different name or add this as a new product.")
                        PrimaryButton(title: "Add “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”") {
                            showAdd = true
                        }
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(matches) { product in
                            Button {
                                router.push(.productFromSearch(product))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(AppFont.inter(16, .medium))
                                        .foregroundStyle(Theme.primaryText)
                                    Text(searchSubtitle(product))
                                        .font(AppFont.inter(14))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            SeparatorLine()
                        }
                    }
                }

                if !query.isEmpty {
                    SecondaryButton(title: "Clear search") {
                        query = ""
                    }
                }

                InfoText(text: "Each brand and variety has its own history. Similar names are not merged.")
                    .padding(.top, 16)
            }
            .onAppear { focused = true }
        }
        .fullScreenCover(isPresented: $showAdd, onDismiss: {
            if let pendingProduct {
                self.pendingProduct = nil
                router.push(pendingProduct.observations.isEmpty ? .productFromSearch(pendingProduct) : .productFirstSave(pendingProduct))
            }
        }) {
            AddProductFlow(mode: .full, initialName: query.trimmingCharacters(in: .whitespacesAndNewlines)) { product in
                pendingProduct = product
                showAdd = false
            }
        }
    }

    private func searchSubtitle(_ product: Product) -> String {
        var parts: [String] = []
        if !product.variety.isEmpty { parts.append(product.variety) }
        parts.append("\(product.storeCount) \(product.storeCount == 1 ? "store" : "stores")")
        parts.append("\(product.observations.count) \(product.observations.count == 1 ? "observation" : "observations")")
        return parts.joined(separator: " · ")
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var saveError = false
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Product.createdAt) private var products: [Product]

    private var activeProducts: [Product] {
        products.filter { !$0.isArchived }
    }

    private var favorites: [Product] {
        activeProducts.filter(\.isFavorite)
    }

    var body: some View {
        ScreenScaffold(saveError: $saveError, title: "Favorites", backLabel: "Journal") {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Text("All products")
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SeparatorLine()

                if favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("No favorites yet")
                            .font(AppFont.inter(16, .medium))
                            .foregroundStyle(Theme.primaryText)
                        InfoText(text: "Mark a product as a favorite to find it quickly on your next visit.")
                        SecondaryButton(title: "Find a product") {
                            router.push(.search)
                        }
                        if let first = activeProducts.first {
                            SecondaryButton(title: "Add \(first.displayName) to favorites") {
                                first.isFavorite = true
                                guard context.saveReportingError(&saveError) else { return }
                            }
                        }
                    }
                    .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(favorites) { product in
                            HStack(spacing: 8) {
                                Button {
                                    router.push(.productFromSearch(product))
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("★")
                                            .font(AppFont.inter(16))
                                            .foregroundStyle(Theme.accent)
                                        JournalProductRow(product: product, observation: product.latestObservation)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    product.isFavorite = false
                                    guard context.saveReportingError(&saveError) else { return }
                                } label: {
                                    Image(systemName: "star.slash")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Theme.secondaryText)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(product.displayName) from favorites")
                            }
                            SeparatorLine()
                        }
                    }

                    InfoText(text: "Frequently tracked products stay easy to find. Their prices and histories are the same as in Journal.")
                        .padding(.top, 8)
                }
            }
        }
    }
}
