import SwiftUI

struct CorrectionLocationView: View {
    let products: [Product]
    let stores: [StoreLocation]
    @Binding var product: Product?
    @Binding var store: StoreLocation?
    @Environment(\.dismiss) private var dismiss
    @State private var localProduct: Product?
    @State private var localStore: StoreLocation?

    var body: some View {
        ScreenScaffold(title: "Product and branch", backLabel: "Cancel", showsBackChevron: false,
            backAction: { dismiss() }, footer: {
                PrimaryButton(title: "Use this location") {
                    product = localProduct
                    store = localStore
                    dismiss()
                }
                .disabled(localProduct == nil || localStore == nil)
            }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                InfoText(text: "Correct the product or branch. The observation and its date are kept.")
                FieldLabel(text: "Product")
                ForEach(products.filter { !$0.isArchived || $0.id == product?.id }) { item in
                    SelectionRow(title: item.displayName, subtitle: nil, isSelected: localProduct?.id == item.id) {
                        localProduct = item
                    }
                }
                FieldLabel(text: "Branch")
                ForEach(stores.filter { !$0.isArchived || $0.id == store?.id }) { item in
                    SelectionRow(title: item.displayName, subtitle: item.city, isSelected: localStore?.id == item.id) {
                        localStore = item
                    }
                }
            }
        }
        .onAppear {
            localProduct = product
            localStore = store
        }
    }
}
