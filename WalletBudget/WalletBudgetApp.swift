import SwiftUI
import SwiftData

/// App entry point. Installs the shared SwiftData container into the environment so every
/// view (and the App Intent, via `SharedModelContainer`) reads and writes the same store.
@main
struct WalletBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            RootGate()
                .onOpenURL { url in
                    handleAuthCallback(url)
                }
        }
        .modelContainer(SharedModelContainer.container)
    }

    /// Completes an OAuth flow when the orbit:// redirect arrives outside the
    /// in-app web session (e.g. the app was backgrounded or relaunched mid-flow).
    /// Non-auth URLs are ignored.
    private func handleAuthCallback(_ url: URL) {
        guard url.scheme == "orbit" else { return }
        Task {
            do {
                try await SupabaseService.client.auth.session(from: url)
                Log.auth.info("OAuth callback URL handled")
            } catch {
                Log.auth.error("OAuth callback failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
