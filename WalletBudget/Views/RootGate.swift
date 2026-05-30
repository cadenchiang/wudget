import SwiftUI

/// Decides what to show at the top level: the welcome landing (which raises the sign-in sheet) when
/// signed out, otherwise the app (behind the optional Face ID lock). Owns and injects `AccountStore`.
struct RootGate: View {
    @State private var account = AccountStore()
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    var body: some View {
        Group {
            if account.isSignedIn {
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
