import Foundation
import Observation

/// The signed-in account, persisted locally.
///
/// This is a local account store (no backend): the login providers record an email + provider
/// name here. Swap `signIn` for real Sign in with Apple / Google / email-backend calls later;
/// the rest of the app only depends on `isSignedIn`, `email`, and `provider`.
@Observable
final class AccountStore {
    var email: String?
    var provider: String?

    var isSignedIn: Bool { email != nil }

    init() {
        email = UserDefaults.standard.string(forKey: Keys.email)
        provider = UserDefaults.standard.string(forKey: Keys.provider)
    }

    /// Records a signed-in account and persists it.
    func signIn(email: String, provider: String) {
        self.email = email
        self.provider = provider
        UserDefaults.standard.set(email, forKey: Keys.email)
        UserDefaults.standard.set(provider, forKey: Keys.provider)
    }

    /// Clears the signed-in account.
    func signOut() {
        email = nil
        provider = nil
        UserDefaults.standard.removeObject(forKey: Keys.email)
        UserDefaults.standard.removeObject(forKey: Keys.provider)
    }

    private enum Keys {
        static let email = "account.email"
        static let provider = "account.provider"
    }
}
