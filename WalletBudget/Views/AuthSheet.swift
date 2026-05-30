import SwiftUI
import AuthenticationServices

/// The sign-in options presented as a bottom sheet from the welcome landing's "Get Started" CTA.
///
/// Apple uses the native Sign in with Apple flow (requires the capability/paid program to authorize
/// on device). Google and Email record a local account via `AccountStore` until those are wired up.
struct AuthSheet: View {
    @Environment(AccountStore.self) private var account
    @State private var showingEmail = false
    @State private var emailInput = ""

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Get started").font(.title2.bold())
                Text("Track your spending automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                providerButton("Continue with Google", icon: "globe",
                               background: Color(.secondarySystemBackground), foreground: .primary, bordered: true) {
                    signIn(provider: "Google", email: "you@gmail.com")
                }
                providerButton("Continue with Email", icon: "envelope.fill",
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
        .sheet(isPresented: $showingEmail) { emailSheet }
    }

    /// Handles the native Sign in with Apple result, recording the account locally.
    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let identity = credential.email ?? (name.isEmpty ? "Apple ID" : name)
            Haptics.success()
            account.signIn(email: identity, provider: "Apple")
        case .failure(let error):
            Log.ui.error("Sign in with Apple failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func providerButton(_ title: String, icon: String, background: Color, foreground: Color,
                                bordered: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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

    private var emailSheet: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $emailInput)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Continue with Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingEmail = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        let trimmed = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        showingEmail = false
                        signIn(provider: "Email", email: trimmed)
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func signIn(provider: String, email: String) {
        Haptics.success()
        account.signIn(email: email, provider: provider)
    }
}
