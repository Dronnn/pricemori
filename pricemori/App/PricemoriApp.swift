import SwiftUI
import SwiftData

@main
struct PricemoriApp: App {
    private let container: ModelContainer

    init() {
        AppFont.registerFonts()

        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        if arguments.contains("-reset-language") {
            UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        }
        #endif
        let inMemory = arguments.contains("-in-memory")
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        let context = container.mainContext
        SampleData.seedIfRequested(context: context)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(nil)
        }
        .modelContainer(container)
    }
}
