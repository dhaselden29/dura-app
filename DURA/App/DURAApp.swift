import SwiftUI
import SwiftData

@main
struct DURAApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            Notebook.self,
            Tag.self,
            Attachment.self,
            Bookmark.self
        ])

        let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isTestEnvironment {
            // Local-only for test runner — CloudKit requires entitlements/signing
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create test ModelContainer: \(error)")
            }
        }

        // Use local storage for now; CloudKit will be enabled once signing is configured
        do {
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
