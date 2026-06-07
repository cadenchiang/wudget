import AuthenticationServices
import SwiftUI

/// Which welcome-screen pill raised the auth sheet. Tailors the sheet copy, the
/// Apple button label, and the email form's starting mode; all providers behave
/// identically underneath (Supabase links by account, not by entry point).
enum AuthIntent: Hashable, Identifiable {
    case signUp
    case logIn

    /// Identity for `.sheet(item:)` presentation; the case itself is the identity.
    var id: Self { self }
}

/// The sign-in options presented as a bottom sheet from the welcome landing's pills.
///
/// All three providers create real Supabase sessions: Apple exchanges the native
/// identity token, Google runs the OAuth flow in a system web session, and Email
/// opens `EmailAuthView` with separate Log in / Sign up modes.
struct AuthSheet: View {
    /// Entry point that raised the sheet; defaults to sign-up for new users.
    var intent: AuthIntent = .signUp

    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmail = false
    @State private var currentNonce: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(intent == .signUp ? "Get started" : "Welcome back")
                    .font(.title2.bold())
                Text(intent == .signUp
                     ? "Track your spending automatically."
                     : "Log in to pick up where you left off.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            VStack(spacing: 12) {
                appleButton
                // Match the Apple button's intent-specific label ("Sign Up with
                // Apple" / "Sign In with Apple") so the sheet never mixes
                // sign-up and sign-in phrasing.
                providerButton(intent == .signUp ? "Sign up with Google" : "Sign in with Google",
                               icon: "logo_google", iconIsAsset: true,
                               background: Color(.secondarySystemBackground), foreground: .primary, bordered: true) {
                    Task { await signInWithGoogle() }
                }
                providerButton(intent == .signUp ? "Sign up with Email" : "Sign in with Email", icon: "envelope.fill",
                               background: Color(.secondarySystemBackground), foreground: .primary, bordered: true) {
                    showingEmail = true
                }
            }

            Text("By continuing, you agree to our Terms & Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView() } }
        .alert("Sign-in failed", isPresented: showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        // Sign-in success is handled one level up: WelcomeLandingView clears the
        // root presentation the moment a session exists, dismissing this sheet
        // and any page above it in a single animation. No dismissal here, so
        // two animations can never race.
        // Full-screen page (not a nested sheet): the email form is a destination
        // in its own right, with room for the keyboard and inline errors.
        .fullScreenCover(isPresented: $showingEmail) {
            EmailAuthView(initialMode: intent == .signUp ? .signUp : .logIn)
        }
    }

    /// Binding that shows the alert whenever an error message is set.
    private var showingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Apple

    private var appleButton: some View {
        SignInWithAppleButton(intent == .signUp ? .signUp : .signIn) { request in
            Haptics.tap()
            do {
                let nonce = try AuthNonce.random()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AuthNonce.sha256(nonce)
            } catch {
                Log.auth.error("Apple request setup failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = "Couldn't start Apple sign-in. Please try again."
            }
        } onCompletion: { result in
            handleApple(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: Self.buttonHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Exchanges the native Sign in with Apple result for a Supabase session.
    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                Log.auth.error("Apple credential missing identity token or nonce")
                errorMessage = "Apple sign-in didn't return a valid credential."
                return
            }
            // Apple provides the full name exactly once (first authorization);
            // capture it now so the profile starts filled in.
            let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            Task {
                isWorking = true
                defer { isWorking = false }
                do {
                    try await account.signInWithApple(idToken: idToken, nonce: nonce)
                    if !appleName.isEmpty, account.displayName == nil {
                        do {
                            try await account.updateDisplayName(appleName)
                        } catch {
                            // Non-fatal: sign-in already succeeded and the name can
                            // be set later in the profile (error logged by the store).
                        }
                    }
                    Haptics.success()
                    // WelcomeLandingView clears the root presentation on
                    // isSignedIn; no explicit dismissal needed here.
                } catch {
                    errorMessage = "Apple sign-in failed. Please try again."
                }
            }
        case .failure(let error):
            // The user closing the Apple dialog is not an error worth surfacing.
            // That arrives as .canceled, but a fast dismissal (or backing out of
            // the Face ID step) reports .unknown (1000) — silence both, log all.
            let code = (error as? ASAuthorizationError)?.code
            Log.auth.error("""
            Sign in with Apple did not complete: code=\(code?.rawValue ?? -1, privacy: .public), \
            \(error.localizedDescription, privacy: .public)
            """)
            guard code != .canceled, code != .unknown else { return }
            errorMessage = "Apple sign-in failed. Please try again."
        }
    }

    // MARK: - Google

    /// Runs the native Google sign-in flow; cancellation is silent, real failures alert.
    private func signInWithGoogle() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await account.signInWithGoogle()
            Haptics.success()
            // WelcomeLandingView clears the root presentation on isSignedIn.
        } catch is CancellationError {
            // The user closing Google's sheet is not an error worth surfacing.
        } catch {
            errorMessage = "Google sign-in failed. Please try again."
        }
    }

    // MARK: - Shared button style

    /// Shared height for every provider button, including the system Apple one.
    private static let buttonHeight: CGFloat = 50

    /// Title size matching what the system Apple button actually draws at
    /// `buttonHeight` (the HIG's "43% of height" spec overshoots the system
    /// rendering; 19pt is the empirical match at 50pt).
    private static let buttonFontSize: CGFloat = 19

    /// Shared chrome for the custom provider buttons, sized to render identically
    /// to the system `SignInWithAppleButton` above them (same height, same
    /// title size/weight). `icon` names an SF Symbol unless `iconIsAsset` is
    /// true, in which case it names a bundled image (the multicolor Google G
    /// has no SF Symbol equivalent).
    private func providerButton(_ title: String, icon: String, iconIsAsset: Bool = false,
                                background: Color, foreground: Color,
                                bordered: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 10) {
                if iconIsAsset {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Self.buttonFontSize, height: Self.buttonFontSize)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.system(size: Self.buttonFontSize, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: Self.buttonHeight)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(foreground)
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(.separator))
                }
            }
        }
    }
}
