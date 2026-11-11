import SwiftUI
import SwiftData

/// The complete journal for a product, independent of chart comparability.
struct ProductHistoryView: View {
    let product: Product
    @EnvironmentObject private var router: AppRouter

    @Environment(\.modelContext) private var context
    @State private var removal: ObservationRemoval?
    @State private var saveError = false

    private var observations: [PriceObservation] { Array(product.sortedObservations.reversed()) }

    var body: some View {
        ScreenScaffold(saveError: $saveError, title: "All observations", backLabel: "Back", scrollsContent: false) {
            List {
                Group {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.displayName).font(AppFont.serif(32))
                        Text(L10n.format("%lld recorded prices", observations.count))
                            .font(AppFont.inter(14)).foregroundStyle(Theme.secondaryText)
                        InfoText(text: "All branches, currencies and conditions")
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .listRowSeparator(.hidden)
                    if removal != nil {
                        SavedBanner(text: "Observation removed") {
                            removal?.restore(product: product, context: context)
                            if context.saveReportingError(&saveError) { removal = nil }
                        }
                        .listRowSeparator(.hidden)
                    }
                    ForEach(observations) { observation in
                        let store = observation.store
                        NavigationLink {
                            ObservationDetailView(product: product, observation: observation, onDelete: { snapshot in
                                if let store { removal = ObservationRemoval(snapshot: snapshot, store: store) }
                            })
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(observation.packagePriceLine).font(AppFont.inter(17, .medium))
                                Text(observation.store?.displayName ?? "")
                                Text("\(Format.timestamp(observation.observedAt)) · \(observation.conditionLine)")
                            }
                            .font(AppFont.inter(14))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.vertical, 8)
                        }
                        .contextMenu {
                            if let store = observation.store {
                                Button("Chart this history") {
                                    router.push(.scopedPriceOverTime(product, store, observation.id))
                                }
                            }
                        }
                    }
                    if observations.isEmpty {
                        InfoText(text: "No prices yet")
                            .padding(.vertical, 16)
                            .listRowSeparator(.hidden)
                    }
                }
                .listRowBackground(Theme.background)
                .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
