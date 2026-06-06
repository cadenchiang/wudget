import GoogleSignIn
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

    /// Completes an OAuth flow when an auth redirect arrives outside the in-app
    /// session: Google's reversed-client-id scheme goes to the Google SDK, the
    /// orbit:// scheme to Supabase (e.g. the app was backgrounded or relaunched
    /// mid-flow). Non-auth URLs are ignored.
    private func handleAuthCallback(_ url: URL) {
        if GIDSignIn.sharedInstance.handle(url) {
            Log.auth.info("Google sign-in callback URL handled")
            return
        }
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
