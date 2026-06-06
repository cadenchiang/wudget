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

/// Full-screen email authentication page with distinct Log in and Sign up modes.
///
/// The mode is fixed by the entry point (which welcome pill was tapped) — there is
/// no in-form mode slider; a footer link flips to the other page for people who
/// picked the wrong one. Sign up sends a verification email (Supabase default) and
/// shows a check-your-inbox state; log in surfaces wrong-credential errors inline
/// and offers a password reset.
struct EmailAuthView: View {
    /// Which flow the page shows. Distinct modes so new users aren't silently
    /// signed up by a typo'd login (and vice versa).
    enum Mode: String, CaseIterable, Identifiable {
        case logIn = "Log in"
        case signUp = "Sign up"
        var id: String { rawValue }
    }

    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var statusMessage: String?
    /// Whether `statusMessage` is an error (red) or neutral info (gray), e.g.
    /// the password-reset confirmation.
    @State private var statusIsError = true
    @State private var awaitingVerification = false

    /// - Parameter initialMode: which mode the form opens in (matches the welcome
    ///   pill the user tapped); the segmented control still allows switching.
    init(initialMode: Mode = .logIn) {
        _mode = State(initialValue: initialMode)
    }

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
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    // MARK: - Form

    /// The email/password page, in the app's monochrome minimal style: plain
    /// fields over hairline underlines (no bubbles, no backgrounds) and a
    /// full-width primary submit button identical to the auth sheet's buttons.
    private var form: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .underlinedField()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .underlinedField()
                }
                .padding(.top, 24)

                if mode == .signUp {
                    Text("At least \(EmailAuthRules.minimumPasswordLength) characters. We'll send a verification email.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                }

                if mode == .logIn {
                    Button("Forgot password?") { Task { await sendReset() } }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .disabled(isWorking)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 12)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // Pinned to the bottom like the welcome page's pills: the switch-mode
        // line directly above the primary action, evenly spaced. The submit pill
        // stays hidden until both fields have content, then springs in.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                switchModeLink
                if bothFieldsFilled {
                    submitButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .animation(.spring(duration: 0.35, bounce: 0.2), value: bothFieldsFilled)
        }
    }

    /// Whether both fields have any content — gates the submit pill's appearance
    /// (full validation still happens in `submit()` with inline messages).
    private var bothFieldsFilled: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    /// One quiet line that flips between the Log in and Sign up pages.
    private var switchModeLink: some View {
        Button {
            mode = mode == .logIn ? .signUp : .logIn
            statusMessage = nil
        } label: {
            (Text(mode == .logIn ? "New to Orbit? " : "Already have an account? ")
                .foregroundStyle(.secondary)
             + Text(mode == .logIn ? "Sign up" : "Log in")
                .foregroundStyle(.primary)
                .fontWeight(.semibold))
        }
        .font(.footnote)
        .buttonStyle(.plain)
    }

    /// The primary submit pill, identical to the welcome page's "Sign up" button:
    /// capsule shape, 56pt tall, headline title, solid primary fill.
    private var submitButton: some View {
        Button(action: { Haptics.tap(); Task { await submit() } }) {
            Group {
                if isWorking {
                    ProgressView().tint(Color(.systemBackground))
                } else {
                    Text(mode.rawValue)
                }
            }
            .font(.headline)
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(Color.primary))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
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

    // MARK: - Actions

    /// Runs the selected flow; on log-in success the root gate swaps to the app,
    /// so this sheet only needs to dismiss itself. Validates inline first (the
    /// submit pill appears as soon as both fields have content).
    private func submit() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        statusIsError = true
        guard EmailAuthRules.isValidEmail(address) else {
            statusMessage = "Please enter a valid email address."
            return
        }
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

    /// Sends the password-reset email and confirms inline. Always tappable: an
    /// empty/invalid email gets a helpful prompt instead of a dead button.
    private func sendReset() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailAuthRules.isValidEmail(address) else {
            statusIsError = true
            statusMessage = "Enter your email above first, then tap Forgot password."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await account.resetPassword(email: address)
            statusIsError = false
            statusMessage = "Password reset email sent. Check your inbox."
        } catch {
            statusIsError = true
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

private extension View {
    /// Minimal field chrome: no background, just a hairline underline in the
    /// primary tone (white in dark mode, black in light), matching the app's
    /// thin-line monochrome aesthetic. Placeholders stay system-gray.
    func underlinedField() -> some View {
        self
            .font(.system(size: 17))
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary)
                    .frame(height: 1)
            }
    }
}
