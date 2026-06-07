import Lottie
import SwiftUI

/// Welcome / landing screen: black and white, with a looping Lottie animation (Al Boardman's
/// minimal geometric "9 squares" loop, recolored monochrome and bundled as welcomeHero.json)
/// in the middle of the screen and simple Sign up / Log in pills at the bottom. Each pill
/// raises the auth sheet with matching intent (copy, Apple button label, email form mode).
struct WelcomeLandingView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.colorScheme) private var colorScheme

    /// Which pill raised the sheet (nil = no sheet). Driving the sheet off the
    /// intent itself (`.sheet(item:)`) guarantees the sheet content is built with
    /// the tapped pill's intent; a separate Bool + `.sheet(isPresented:)` can
    /// evaluate the content closure with a stale intent on first presentation.
    @State private var authIntent: AuthIntent?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Centered in the space above the buttons (not the full screen), so the
                // animation sits at the optical center rather than reading low.
                Spacer()
                hero
                Spacer()
                authButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .sheet(item: $authIntent) { intent in
            AuthSheet(intent: intent)
                .environment(account)
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        // The ONE place the auth UI is torn down after any successful sign-in:
        // clearing the root presentation dismisses the sheet and the email
        // page above it in a single animation. (Dismissing layer by layer
        // made a successful login linger on the email page, then the sheet,
        // before the app finally appeared.)
        .onChange(of: account.isSignedIn) { _, signedIn in
            if signedIn { authIntent = nil }
        }
    }

    /// The hero: the morphing monochrome ring loop, nothing else.
    private var hero: some View {
        LottieView(animation: .named("welcomeHero"))
            .playing(loopMode: .loop)
            // The artwork is authored black; flip every stroke/fill white in dark mode so
            // the line art stays visible on either system background.
            .valueProvider(
                ColorValueProvider(colorScheme == .dark
                    ? LottieColor(r: 1, g: 1, b: 1, a: 1)
                    : LottieColor(r: 0, g: 0, b: 0, a: 1)),
                for: AnimationKeypath(keypath: "**.Color")
            )
            .frame(width: 300, height: 300)
    }

    /// The bottom CTAs: a solid Sign up pill over an outlined Log in pill, both monochrome.
    private var authButtons: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                authIntent = .signUp
            } label: {
                Text("Sign up")
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.primary))
            }
            Button {
                Haptics.tap()
                authIntent = .logIn
            } label: {
                Text("Log in")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeLandingView()
        .environment(AccountStore())
}
