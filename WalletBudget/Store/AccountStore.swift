import Foundation
import Observation
import Supabase

/// The signed-in account, backed by Supabase Auth.
///
/// Wraps the shared Supabase auth client: restores the persisted session on launch,
/// mirrors auth state into the observable properties the UI depends on (`isSignedIn`,
/// `email`, `provider`), and exposes the sign-in/up/out entry points used by the
/// auth UI. Session tokens are persisted by supabase-swift in the keychain; this
/// store never stores credentials itself.
@Observable
@MainActor
final class AccountStore {
    /// Email of the signed-in user; nil when signed out.
    private(set) var email: String?

    /// Display name of the auth provider ("Apple", "Google", "Email"); nil when signed out.
    private(set) var provider: String?

    /// User-chosen display name from Supabase user metadata; nil when unset or signed out.
    private(set) var displayName: String?

    /// True until the initial session restore completes, so the root view can hold
    /// a splash instead of flashing the welcome screen at every cold launch.
    private(set) var isRestoringSession = true

    var isSignedIn: Bool { email != nil }

    /// Redirect URL for OAuth flows (registered as a custom URL scheme and in the
    /// Supabase dashboard's Redirect URLs allowlist).
    static let oauthRedirectURL = URL(string: "orbit://auth-callback")!

    private let auth: AuthClient
    /// Set once in init, cancelled in deinit; `nonisolated(unsafe)` because deinit
    /// is nonisolated and there is no concurrent mutation of this property.
    private nonisolated(unsafe) var observeTask: Task<Void, Never>?

    /// - Parameter auth: the Supabase auth client (injectable for tests/previews).
    init(auth: AuthClient = SupabaseService.client.auth) {
        self.auth = auth
        Self.purgeLegacyLocalAccount()
        observeTask = Task { [weak self] in await self?.observeAuthChanges() }
    }

    deinit { observeTask?.cancel() }

    // MARK: - Session observation

    /// Mirrors every Supabase auth state change into the published properties.
    /// The stream emits `.initialSession` immediately (restored or nil session),
    /// which ends the restore phase.
    private func observeAuthChanges() async {
        for await (event, session) in auth.authStateChanges {
            if let user = session?.user {
                // A different account signing in on this device must never see the
                // previous owner's expenses, budget, photo, or preferences.
                if AccountDataReset.isDifferentOwner(than: user.id.uuidString) {
                    AccountDataReset.wipeAllLocalData()
                }
                AccountDataReset.recordOwner(userID: user.id.uuidString)
                // Pull this account's cloud data (and push anything local) so any
                // device shows the same expenses after sign-in.
                SyncEngine.shared.requestSync()
            }
            let identity = Self.identity(email: session?.user.email,
                                         appMetadata: session?.user.appMetadata)
            email = identity.email
            provider = identity.provider
            displayName = Self.displayName(from: session?.user.userMetadata)
            if event == .initialSession { isRestoringSession = false }
            Log.auth.info("""
            Auth state changed: \(event.rawValue, privacy: .public), \
            signedIn=\(self.isSignedIn), provider=\(self.provider ?? "none", privacy: .public)
            """)
        }
    }

    // MARK: - Sign in / up

    /// Exchanges a native Sign in with Apple identity token for a Supabase session.
    /// - Parameters:
    ///   - idToken: the JWT from `ASAuthorizationAppleIDCredential.identityToken`.
    ///   - nonce: the raw nonce whose SHA-256 hash was attached to the Apple request.
    /// - Throws: `AuthError` when the token is rejected (e.g. bundle id not in the
    ///   provider's Authorized Client IDs).
    func signInWithApple(idToken: String, nonce: String) async throws {
        do {
            try await auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            Log.auth.info("Apple sign-in succeeded")
        } catch {
            Log.auth.error("Apple sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Runs the Google OAuth flow in an `ASWebAuthenticationSession` and signs in.
    /// - Throws: `AuthError` on cancellation or provider misconfiguration.
    func signInWithGoogle() async throws {
        do {
            try await auth.signInWithOAuth(provider: .google, redirectTo: Self.oauthRedirectURL)
            Log.auth.info("Google sign-in succeeded")
        } catch {
            Log.auth.error("Google sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Signs in an existing email+password account.
    /// - Throws: `AuthError` for wrong password, unknown account, or unverified email.
    func signIn(email: String, password: String) async throws {
        do {
            try await auth.signIn(email: email, password: password)
            Log.auth.info("Email sign-in succeeded")
        } catch {
            Log.auth.error("Email sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Creates a new email+password account.
    /// - Returns: true when Supabase requires email verification before the first
    ///   session is granted (the UI should show a "check your inbox" state).
    /// - Throws: `AuthError` for duplicate accounts or weak passwords.
    func signUp(email: String, password: String) async throws -> Bool {
        do {
            let result = try await auth.signUp(email: email, password: password)
            let needsVerification = result.session == nil
            Log.auth.info("Email sign-up succeeded, needsVerification=\(needsVerification)")
            return needsVerification
        } catch {
            Log.auth.error("Email sign-up failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Sends a password-reset email.
    /// - Throws: `AuthError` when the email cannot be sent.
    func resetPassword(email: String) async throws {
        do {
            try await auth.resetPasswordForEmail(email)
            Log.auth.info("Password reset email sent")
        } catch {
            Log.auth.error("Password reset failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    // MARK: - Sign out

    /// Clears local state immediately (so the UI responds without waiting on the
    /// network) and revokes the Supabase session in the background. A failed remote
    /// revoke is logged but not surfaced: the local session is already discarded,
    /// so the user-visible outcome (signed out) is unaffected.
    func signOut() {
        email = nil
        provider = nil
        displayName = nil
        // Stop any in-flight sync (its session is ending) and clear the surfaces
        // that show financial data on the home/lock screen while nobody is signed
        // in. The database stays (the same owner usually returns; a different
        // sign-in wipes it).
        SyncEngine.shared.cancelAll()
        AccountDataReset.clearSignedOutSurfaces()
        Task {
            do {
                try await auth.signOut()
                Log.auth.info("Sign-out completed")
            } catch {
                Log.auth.error("Remote sign-out failed (local state already cleared): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Profile

    /// Saves the user's display name to Supabase user metadata. The auth state
    /// stream emits `.userUpdated` with the fresh session, which republishes
    /// `displayName`, so no manual state write is needed here.
    /// - Parameter name: the new name; whitespace-trimmed, empty clears the name.
    /// - Throws: `AuthError` when the update fails (UI keeps the old name).
    func updateDisplayName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await auth.update(user: UserAttributes(data: ["display_name": .string(trimmed)]))
            Log.auth.info("Display name updated")
        } catch {
            Log.auth.error("Display name update failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// Extracts a non-empty display name from Supabase user metadata.
    /// - Parameter metadata: the session user's `user_metadata`.
    /// - Returns: the trimmed name, or nil when missing/blank.
    nonisolated static func displayName(from metadata: [String: AnyJSON]?) -> String? {
        guard let raw = metadata?["display_name"]?.stringValue else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Account deletion

    /// Permanently deletes the account (App Store guideline 5.1.1(v)).
    ///
    /// Calls the `delete_user` Postgres RPC, which is SECURITY DEFINER and scoped
    /// to `auth.uid()`, so a user can only ever delete themselves. On success all
    /// on-device data (expenses, preferences, photo) is wiped and the local
    /// session cleared, so deletion is total: server account and device data.
    /// - Throws: the RPC error; session and local data are kept so the user can retry.
    func deleteAccount() async throws {
        do {
            try await SupabaseService.client.rpc("delete_user").execute()
            Log.auth.notice("Account deleted server-side")
        } catch {
            Log.auth.error("Account deletion failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        AccountDataReset.wipeAllLocalData()
        signOut()
    }

    // MARK: - Identity mapping

    /// Derives the display identity from a session's user fields.
    ///
    /// - Parameters:
    ///   - email: the user's email, nil when there is no session.
    ///   - appMetadata: Supabase `app_metadata`, whose "provider" key names the
    ///     sign-in method ("apple", "google", "email").
    /// - Returns: nils when signed out; otherwise the email plus a display-cased
    ///   provider name (unknown providers are capitalized, missing ones become "Account").
    nonisolated static func identity(email: String?, appMetadata: [String: AnyJSON]?) -> (email: String?, provider: String?) {
        guard let email, !email.isEmpty else { return (nil, nil) }
        switch appMetadata?["provider"]?.stringValue {
        case "apple": return (email, "Apple")
        case "google": return (email, "Google")
        case "email": return (email, "Email")
        case let .some(other) where !other.isEmpty: return (email, other.capitalized)
        default: return (email, "Account")
        }
    }

    /// Removes the pre-Supabase locally-stored account (UserDefaults stub) so stale
    /// identities from old builds don't linger alongside real sessions.
    /// Internal (not private) so tests can exercise it directly.
    nonisolated static func purgeLegacyLocalAccount() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: LegacyKeys.email) != nil
                || defaults.object(forKey: LegacyKeys.provider) != nil else { return }
        defaults.removeObject(forKey: LegacyKeys.email)
        defaults.removeObject(forKey: LegacyKeys.provider)
        Log.auth.notice("Purged legacy local account stub from UserDefaults")
    }

    private enum LegacyKeys {
        static let email = "account.email"
        static let provider = "account.provider"
    }
}
