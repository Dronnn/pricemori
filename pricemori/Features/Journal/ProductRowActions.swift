import SwiftUI
import SwiftData

/// Shortcuts supplement the visible actions on Product and Edit product.
struct ProductRowActions: ViewModifier {
    let product: Product
    var store: StoreLocation?
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var showRecord = false
    @State private var savedObservation: PriceObservation?
    @State private var confirmArchive = false
    @State private var confirmDelete = false
    @State private var saveError = false

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button { showRecord = true } label: { Label("Record a price", systemImage: "plus") }
                    .tint(Theme.accent)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button { confirmArchive = true } label: { Label("Archive", systemImage: "archivebox") }
                    .tint(.gray)
                Button { toggleFavorite() } label: {
                    Label(L10n.string(product.isFavorite ? "Unfavorite" : "Favorite"), systemImage: product.isFavorite ? "star.slash" : "star")
                }.tint(Theme.accent)
            }
            .contextMenu {
                Button { showRecord = true } label: { Label("Record a price", systemImage: "plus") }
                Button { router.push(.allHistory(product)) } label: { Label("History", systemImage: "clock") }
                Button { toggleFavorite() } label: {
                    Label(L10n.string(product.isFavorite ? "Unfavorite" : "Favorite"), systemImage: "star")
                }
                Button { confirmArchive = true } label: { Label("Archive", systemImage: "archivebox") }
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete product…", systemImage: "trash") }
            }
            .fullScreenCover(isPresented: $showRecord, onDismiss: {
                if let savedObservation {
                    self.savedObservation = nil
                    router.push(.productAfterRecording(product, savedObservation.id))
                }
            }) {
                RecordPriceView(product: product, initialStore: store) { savedObservation = $0 }
            }
            .alert("Stop tracking this product?", isPresented: $confirmArchive) {
                Button("Keep tracking", role: .cancel) {}
                Button("Archive") {
                    product.isArchived = true
                    product.archivedAt = .now
                    _ = context.saveReportingError(&saveError)
                }
            } message: {
                Text("Its history is kept. Restore it from Archived products.")
            }
            .alert("Delete product permanently?", isPresented: $confirmDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete product", role: .destructive) {
                    context.delete(product)
                    _ = context.saveReportingError(&saveError)
                }
            } message: {
                Text(L10n.format("Delete %@ and all %lld recorded prices? This cannot be undone.", product.name, product.observations.count) + "\n" + L10n.string("Archive it instead to keep its history."))
            }
            .alert("Could not save changes", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: { Text("Your changes were not saved. Please try again.") }
    }

    private func toggleFavorite() {
        product.isFavorite.toggle()
        _ = context.saveReportingError(&saveError)
    }
}
