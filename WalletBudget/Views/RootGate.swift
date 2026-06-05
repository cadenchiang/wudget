import SwiftUI

/// Decides what to show at the top level: the welcome landing (which raises the sign-in sheet) when
/// signed out, otherwise the app (behind the optional Face ID lock). Owns and injects `AccountStore`.
struct RootGate: View {
    @State private var account = AccountStore()
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    var body: some View {
        Group {
            if account.isRestoringSession {
                // Hold a neutral splash while Supabase restores the persisted
                // session, so cold launches don't flash the welcome screen.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if account.isSignedIn {
                AppLockGate { RootView() }
            } else {
                WelcomeLandingView()
            }
        }
        .environment(account)
        .animation(.easeInOut, value: account.isSignedIn)
        .preferredColorScheme(theme.colorScheme)
    }
}
