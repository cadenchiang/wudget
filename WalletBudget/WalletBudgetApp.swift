import SwiftUI
import SwiftData

/// App entry point. Installs the shared SwiftData container into the environment so every
/// view (and the App Intent, via `SharedModelContainer`) reads and writes the same store.
@main
struct WalletBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(SharedModelContainer.container)
    }
}
