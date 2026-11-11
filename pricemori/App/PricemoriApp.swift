import SwiftUI
import SwiftData

@main
struct PricemoriApp: App {
    @State private var container: ModelContainer?

    init() {
        AppFont.registerFonts()

        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        if arguments.contains("-reset-language") {
            UserDefaults.standard.set(AppLanguage.english.rawValue, forKey: AppLanguage.storageKey)
        }
        if arguments.contains("-reset-onboarding") {
            UserDefaults.standard.set(false, forKey: Onboarding.storageKey)
        }
        if arguments.contains("-skip-onboarding") {
            UserDefaults.standard.set(true, forKey: Onboarding.storageKey)
        }
        #endif
        let inMemory = arguments.contains("-in-memory")
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            let created = try ModelContainer(for: schema, configurations: [configuration])
            _container = State(initialValue: created)
            SampleData.seedIfRequested(context: created.mainContext)
        } catch {
            _container = State(initialValue: nil)
        }

    }

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .preferredColorScheme(testColorScheme)
                    .modelContainer(container)
            } else {
                ContentUnavailableView {
                    Label("Could not open your journal", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your stored journal has not been deleted. Free some storage and restart the app, or try again.")
                } actions: {
                    Button("Try again") { retryOpeningJournal() }
                }
            }
        }
    }

    private var testColorScheme: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dark-mode") { return .dark }
        #endif
        return nil
    }

    private func retryOpeningJournal() {
        let schema = Schema([Product.self, StoreLocation.self, PriceObservation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("-in-memory"))
        container = try? ModelContainer(for: schema, configurations: [configuration])
    }
}
