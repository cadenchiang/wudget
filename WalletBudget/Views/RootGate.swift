import SwiftUI

/// Decides what to show at the top level: the login screen when signed out, otherwise the app
/// (behind the optional Face ID lock). Owns and injects the shared `AccountStore`.
///
/// The personal onboarding flow is disabled for now; launch goes straight to login.
struct RootGate: View {
    @State private var account = AccountStore()
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    var body: some View {
        Group {
            if account.isSignedIn {
                AppLockGate { RootView() }
            } else {
                LoginView()
            }
        }
        .environment(account)
        .animation(.easeInOut, value: account.isSignedIn)
        .preferredColorScheme(theme.colorScheme)
    }
}
