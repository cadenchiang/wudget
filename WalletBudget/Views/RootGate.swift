import SwiftUI

/// Decides what to show at the top level: the welcome landing (which raises the sign-in sheet) when
/// signed out, otherwise the app (behind the optional Face ID lock). Owns and injects `AccountStore`.
struct RootGate: View {
    @State private var account = AccountStore()
    /// Which tree is shown. Deliberately lags `account.isSignedIn` after an
    /// interactive sign-in: swapping the tree the instant the session lands rips
    /// the still-presented auth sheet out from under UIKit mid-dismissal, which
    /// reads as a glitchy, low-quality transition. Instead the sheet animates
    /// away over the welcome screen, then the app cross-fades in.
    @State private var showApp = false
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    /// How long to let the auth stack finish dismissing before swapping trees.
    /// The welcome screen tears the whole stack down in ONE animation (sheet +
    /// email page together), so this only needs to cover a single dismissal.
    private static let sheetDismissDelay: TimeInterval = 0.5

    var body: some View {
        Group {
            if account.isRestoringSession {
                // Hold a neutral splash while Supabase restores the persisted
                // session, so cold launches don't flash the welcome screen.
                // Deliberately a bare background — identical to the launch
                // screen and the lock screen behind it — so launch reads as
                // one continuous surface. A spinner here flashed for a split
                // second on every cold launch and looked broken.
                Color(.systemBackground)
                    .ignoresSafeArea()
            } else if showApp {
                AppLockGate { RootView() }
                    .transition(.opacity)
            } else {
                WelcomeLandingView()
                    .transition(.opacity)
            }
        }
        .environment(account)
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: account.isSignedIn, initial: true) { _, signedIn in
            syncShowApp(signedIn: signedIn)
        }
    }

    /// Mirrors `isSignedIn` into `showApp`, delaying the welcome→app swap after an
    /// interactive sign-in so the auth sheet's dismiss animation completes first.
    /// Cold-launch session restores (no sheet up) swap immediately, so the splash
    /// never gives way to a flash of the welcome screen.
    private func syncShowApp(signedIn: Bool) {
        guard signedIn else {
            withAnimation(.easeInOut(duration: 0.3)) { showApp = false }
            return
        }
        guard account.lastSignInWasInteractive else {
            showApp = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sheetDismissDelay) {
            // Re-check: a sign-out during the delay must not resurface the app.
            guard account.isSignedIn else { return }
            withAnimation(.easeInOut(duration: 0.45)) { showApp = true }
        }
    }
}
