import SwiftUI

/// Sign-in screen with Continue with Apple / Google / Email.
///
/// Currently backed by a local account (`AccountStore`); each button records an account locally.
/// Replace the `signIn` calls with real provider SDK flows when those are configured.
struct LoginView: View {
    @Environment(AccountStore.self) private var account
    @State private var showingEmail = false
    @State private var emailInput = ""

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            branding
            Spacer()
            providers
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .sheet(isPresented: $showingEmail) { emailSheet }
    }

    private var branding: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.primary)
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color(.systemBackground))
                }
            Text("Wudget").font(.largeTitle.bold())
            Text("Track your spending automatically")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var providers: some View {
        VStack(spacing: 12) {
            providerButton("Continue with Apple", icon: "applelogo",
                           background: .primary, foreground: Color(.systemBackground)) {
                signIn(provider: "Apple", email: "you@privaterelay.appleid.com")
            }
            providerButton("Continue with Google", icon: "globe",
                           background: Color(.secondarySystemBackground), foreground: .primary, bordered: true) {
                signIn(provider: "Google", email: "you@gmail.com")
            }
            providerButton("Continue with Email", icon: "envelope.fill",
                           background: Color(.secondarySystemBackground), foreground: .primary, bordered: true) {
                showingEmail = true
            }
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
