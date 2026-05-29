import SwiftUI

/// The pre-app launch routes shown before the user reaches the signed-in app.
enum LaunchRoute {
    /// The welcome landing screen (Get Started / Sign In).
    case landing
    /// The first-launch personal onboarding questionnaire.
    case onboarding
    /// The sign-in screen.
    case login
}

/// Decides what to show at the top level. Once signed in, shows the app (behind the optional Face
/// ID lock). Otherwise it walks the launch flow: a welcome landing where "Get Started" runs
/// onboarding (then sign-in) and "Sign In" goes straight to login. Owns and injects the shared
/// `AccountStore`.
struct RootGate: View {
    @State private var account = AccountStore()
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    /// Where to resume the launch flow. If onboarding was already completed on a prior launch we
    /// skip straight to login; otherwise we begin at the welcome landing.
    @State private var route: LaunchRoute = UserDefaults.standard.bool(forKey: ProfileKeys.completed) ? .login : .landing

    var body: some View {
        Group {
            if account.isSignedIn {
                AppLockGate { RootView() }
            } else {
                launchFlow
            }
        }
        .environment(account)
        .animation(.easeInOut, value: account.isSignedIn)
        .animation(.easeInOut, value: route)
        .preferredColorScheme(theme.colorScheme)
    }

    @ViewBuilder
    private var launchFlow: some View {
        switch route {
        case .landing:
            WelcomeLandingView(
                onGetStarted: { route = .onboarding },
                onSignIn: { route = .login }
            )
        case .onboarding:
            // After finishing onboarding, new users sign in before entering the app. Backing out
            // of the first step returns to the welcome landing.
            PersonalOnboardingFlow(
                onComplete: { route = .login },
                onExit: { route = .landing }
            )
        case .login:
            LoginView()
        }
    }
}
