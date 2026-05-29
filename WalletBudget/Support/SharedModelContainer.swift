import Foundation
import SwiftData

/// Provides the single SwiftData container shared by the SwiftUI app and the App Intent.
///
/// Both the UI (via `.modelContainer`) and `AddTransactionIntent` read/write the same
/// on-disk store through this container, so a transaction logged by the Shortcut appears
/// in the app immediately. App Intents declared in the main app target run in the app's
/// process, so a plain default container (no App Group entitlement) is sufficient.
enum SharedModelContainer {
    /// The process-wide container. Construction failure is unrecoverable, so we log and trap.
    static let container: ModelContainer = {
        do {
            let schema = Schema([Expense.self, SpendingCategory.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            Log.store.info("SwiftData container initialized")
            return container
        } catch {
            Log.store.critical("Failed to create ModelContainer: \(error.localizedDescription, privacy: .public)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
