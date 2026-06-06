import XCTest
@testable import WalletBudget

/// Unit tests for the pure auth logic: nonce generation, email/password validation,
/// identity mapping, error copy, and the legacy local-account purge.
final class AuthLogicTests: XCTestCase {
    // MARK: - AuthNonce

    /// Generated nonces have the requested length and stay in the URL-safe charset.
    func testNonceLengthAndCharset() throws {
        let nonce = try AuthNonce.random()
        XCTAssertEqual(nonce.count, 32)
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        XCTAssertTrue(nonce.unicodeScalars.allSatisfy(allowed.contains))

        let short = try AuthNonce.random(length: 8)
        XCTAssertEqual(short.count, 8)
    }

    /// Two nonces should never collide (probabilistic, but at 32 chars it's safe).
    func testNonceUniqueness() throws {
        XCTAssertNotEqual(try AuthNonce.random(), try AuthNonce.random())
    }

    /// SHA-256 matches a known test vector (so the Apple request hash is correct).
    func testSHA256KnownVector() {
        XCTAssertEqual(
            AuthNonce.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    // MARK: - EmailAuthRules

    /// Email validation accepts normal addresses and rejects malformed ones.
    func testEmailValidation() {
        XCTAssertTrue(EmailAuthRules.isValidEmail("caden@example.com"))
        XCTAssertTrue(EmailAuthRules.isValidEmail("  caden@example.com  ")) // trimmed
        XCTAssertFalse(EmailAuthRules.isValidEmail(""))
        XCTAssertFalse(EmailAuthRules.isValidEmail("caden"))
        XCTAssertFalse(EmailAuthRules.isValidEmail("caden@"))
        XCTAssertFalse(EmailAuthRules.isValidEmail("@example.com"))
        XCTAssertFalse(EmailAuthRules.isValidEmail("caden@nodot"))
        XCTAssertFalse(EmailAuthRules.isValidEmail("a@b@c.com"))
        XCTAssertFalse(EmailAuthRules.isValidEmail("caden@.com"))
        XCTAssertFalse(EmailAuthRules.isValidEmail("caden@com."))
    }

    /// Password rule flags short passwords and passes acceptable ones.
    func testPasswordIssue() {
        XCTAssertNotNil(EmailAuthRules.passwordIssue(""))
        XCTAssertNotNil(EmailAuthRules.passwordIssue("12345"))
        XCTAssertNil(EmailAuthRules.passwordIssue("123456"))
        XCTAssertNil(EmailAuthRules.passwordIssue("a-much-longer-password"))
    }

    // MARK: - Identity mapping

    /// Known providers map to display names; nil/empty email means signed out.
    func testIdentityMapping() {
        XCTAssertEqual(AccountStore.identity(email: "a@b.com", appMetadata: ["provider": .string("apple")]).provider, "Apple")
        XCTAssertEqual(AccountStore.identity(email: "a@b.com", appMetadata: ["provider": .string("google")]).provider, "Google")
        XCTAssertEqual(AccountStore.identity(email: "a@b.com", appMetadata: ["provider": .string("email")]).provider, "Email")
        XCTAssertEqual(AccountStore.identity(email: "a@b.com", appMetadata: ["provider": .string("github")]).provider, "Github")
        XCTAssertEqual(AccountStore.identity(email: "a@b.com", appMetadata: nil).provider, "Account")

        let signedOut = AccountStore.identity(email: nil, appMetadata: nil)
        XCTAssertNil(signedOut.email)
        XCTAssertNil(signedOut.provider)
        XCTAssertNil(AccountStore.identity(email: "", appMetadata: nil).email)
    }

    // MARK: - Display name

    /// Display name extraction trims whitespace and treats blank as unset.
    func testDisplayNameExtraction() {
        XCTAssertEqual(AccountStore.displayName(from: ["display_name": .string("Caden")]), "Caden")
        XCTAssertEqual(AccountStore.displayName(from: ["display_name": .string("  Caden C  ")]), "Caden C")
        XCTAssertNil(AccountStore.displayName(from: ["display_name": .string("   ")]))
        XCTAssertNil(AccountStore.displayName(from: ["display_name": .string("")]))
        XCTAssertNil(AccountStore.displayName(from: [:]))
        XCTAssertNil(AccountStore.displayName(from: nil))
    }

    // MARK: - Error copy

    /// Server errors map to actionable copy, never raw messages.
    func testFriendlyMessages() {
        struct Fake: LocalizedError { let errorDescription: String? }
        XCTAssertTrue(
            EmailAuthView.friendlyMessage(for: Fake(errorDescription: "Invalid login credentials"), mode: .logIn)
                .contains("Wrong email or password")
        )
        XCTAssertTrue(
            EmailAuthView.friendlyMessage(for: Fake(errorDescription: "User already registered"), mode: .signUp)
                .contains("already has an account")
        )
        XCTAssertTrue(
            EmailAuthView.friendlyMessage(for: Fake(errorDescription: "Email not confirmed"), mode: .logIn)
                .contains("verify your email")
        )
        XCTAssertTrue(
            EmailAuthView.friendlyMessage(for: Fake(errorDescription: "weird"), mode: .logIn)
                .contains("log in")
        )
    }

    // MARK: - Private relay detection

    /// Apple private-relay addresses are detected (any casing); normal ones are not.
    func testPrivateRelayDetection() {
        XCTAssertTrue(AccountView.isPrivateRelay("x9f3kq2@privaterelay.appleid.com"))
        XCTAssertTrue(AccountView.isPrivateRelay("ABC123@PRIVATERELAY.APPLEID.COM"))
        XCTAssertFalse(AccountView.isPrivateRelay("caden@example.com"))
        XCTAssertFalse(AccountView.isPrivateRelay("someone@appleid.com"))
        XCTAssertFalse(AccountView.isPrivateRelay(""))
    }

    // MARK: - Interactive sign-in grace

    /// The grace is one-shot: false by default, true exactly once after an
    /// interactive sign-in is marked, then reset by consumption.
    @MainActor
    func testInteractiveSignInGraceIsOneShot() {
        let account = AccountStore()
        XCTAssertFalse(account.lastSignInWasInteractive)
        XCTAssertFalse(account.consumeInteractiveSignInGrace())

        account.markInteractiveSignIn()
        XCTAssertTrue(account.lastSignInWasInteractive)
        XCTAssertTrue(account.consumeInteractiveSignInGrace())

        XCTAssertFalse(account.lastSignInWasInteractive)
        XCTAssertFalse(account.consumeInteractiveSignInGrace())
    }

    // NOTE: signOut() clearing the grace is intentionally not unit-tested here:
    // AccountStore.signOut() revokes the real keychain session and clears real
    // surfaces, which must never happen as a test side effect on a device.

    // MARK: - Legacy purge

    /// The pre-Supabase UserDefaults stub is removed on first run.
    func testPurgeLegacyLocalAccount() {
        let defaults = UserDefaults.standard
        defaults.set("old@stub.com", forKey: "account.email")
        defaults.set("Email", forKey: "account.provider")

        AccountStore.purgeLegacyLocalAccount()

        XCTAssertNil(defaults.string(forKey: "account.email"))
        XCTAssertNil(defaults.string(forKey: "account.provider"))
    }
}
