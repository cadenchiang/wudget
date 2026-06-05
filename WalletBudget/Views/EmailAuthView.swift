import SwiftUI

/// Validation rules for the email auth form (kept as pure functions for testability).
enum EmailAuthRules {
    /// Minimum password length; matches the Supabase project default so the client
    /// never accepts a password the server would reject.
    static let minimumPasswordLength = 6

    /// Lightweight email shape check (full validation is the server's job).
    /// - Parameter email: candidate address.
    /// - Returns: true when the input looks like user@host.tld.
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let host = parts[1]
        return host.contains(".") && !host.hasPrefix(".") && !host.hasSuffix(".")
    }

    /// Describes why a password is unacceptable, or nil when it is fine.
    /// - Parameter password: candidate password.
    /// - Returns: a user-facing message, or nil when valid.
    static func passwordIssue(_ password: String) -> String? {
        guard password.count >= minimumPasswordLength else {
            return "Password must be at least \(minimumPasswordLength) characters."
        }
        return nil
    }
}

/// Email authentication form with distinct Log in and Sign up modes.
///
/// Sign up sends a verification email (Supabase default) and shows a check-your-inbox
/// state; log in surfaces wrong-credential errors inline and offers a password reset.
struct EmailAuthView: View {
    /// Which flow the form is in. Distinct modes so new users aren't silently
    /// signed up by a typo'd login (and vice versa).
    enum Mode: String, CaseIterable, Identifiable {
        case logIn = "Log in"
        case signUp = "Sign up"
        var id: String { rawValue }
    }

    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .logIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var awaitingVerification = false

    var body: some View {
        NavigationStack {
            Group {
                if awaitingVerification {
                    verificationPending
                } else {
                    form
                }
            }
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isWorking)
    }

    // MARK: - Form

    private var form: some View {
        Form {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .onChange(of: mode) { _, _ in statusMessage = nil }

            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                SecureField("Password", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
            } footer: {
                if mode == .signUp {
                    Text("At least \(EmailAuthRules.minimumPasswordLength) characters. We'll send a verification email.")
                }
            }

            Section {
                Button(action: { Task { await submit() } }) {
                    if isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(mode.rawValue).fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                }
                .disabled(isWorking || !inputsLookValid)

                if mode == .logIn {
                    Button("Forgot password?") { Task { await sendReset() } }
                        .font(.footnote)
                        .disabled(isWorking || !EmailAuthRules.isValidEmail(email))
                }
            }

            if let statusMessage {
                Section {
                    Text(statusMessage).font(.footnote).foregroundStyle(.red)
                }
            }
        }
    }

    /// The check-your-inbox state shown after a sign-up that requires verification.
    private var verificationPending: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
                .foregroundStyle(.primary)
            Text("Check your inbox").font(.headline)
            Text("We sent a verification link to \(email). Verify, then log in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("I've verified, log me in") {
                awaitingVerification = false
                mode = .logIn
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    /// Client-side sanity check used to enable the submit button.
    private var inputsLookValid: Bool {
        EmailAuthRules.isValidEmail(email) && EmailAuthRules.passwordIssue(password) == nil
    }

    // MARK: - Actions

    /// Runs the selected flow; on log-in success the root gate swaps to the app,
    /// so this sheet only needs to dismiss itself.
    private func submit() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = EmailAuthRules.passwordIssue(password) {
            statusMessage = issue
            return
        }
        isWorking = true
        defer { isWorking = false }
        statusMessage = nil
        do {
            switch mode {
            case .logIn:
                try await account.signIn(email: address, password: password)
                Haptics.success()
                dismiss()
            case .signUp:
                let needsVerification = try await account.signUp(email: address, password: password)
                Haptics.success()
                if needsVerification {
                    awaitingVerification = true
                } else {
                    dismiss()
                }
            }
        } catch {
            statusMessage = Self.friendlyMessage(for: error, mode: mode)
        }
    }

    /// Sends the password-reset email and confirms inline.
    private func sendReset() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await account.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            statusMessage = "Password reset email sent. Check your inbox."
        } catch {
            statusMessage = "Couldn't send the reset email. Please try again."
        }
    }

    /// Maps auth errors to copy a person can act on (never raw server messages).
    /// - Parameters:
    ///   - error: the thrown auth error.
    ///   - mode: which flow produced it (wording differs).
    /// - Returns: a short, user-facing message.
    static func friendlyMessage(for error: Error, mode: Mode) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("invalid login credentials") {
            return "Wrong email or password. If you're new, switch to Sign up."
        }
        if text.contains("already registered") {
            return "That email already has an account. Switch to Log in."
        }
        if text.contains("email not confirmed") {
            return "Please verify your email first. Check your inbox for the link."
        }
        if text.contains("password") {
            return "Password must be at least \(EmailAuthRules.minimumPasswordLength) characters."
        }
        return mode == .logIn
            ? "Couldn't log in. Please try again."
            : "Couldn't create the account. Please try again."
    }
}
