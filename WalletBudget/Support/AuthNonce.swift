import CryptoKit
import Foundation
import Security

/// Nonce utilities for Sign in with Apple.
///
/// Apple's flow requires sending the SHA-256 hash of a one-time random nonce with
/// the authorization request, then presenting the raw nonce when exchanging the
/// identity token (Supabase verifies the pair to block replay attacks).
enum AuthNonce {
    /// Error raised when the system cannot produce secure random bytes.
    enum Failure: Error, Equatable {
        case randomGenerationFailed(OSStatus)
    }

    /// Characters used in generated nonces (URL-safe, per Apple's sample).
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    /// Generates a cryptographically secure random nonce.
    /// - Parameter length: number of characters (default 32; must be > 0).
    /// - Returns: a random string drawn from the URL-safe charset.
    /// - Throws: `Failure.randomGenerationFailed` when SecRandomCopyBytes fails.
    static func random(length: Int = 32) throws -> String {
        precondition(length > 0, "Nonce length must be positive")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            Log.auth.error("Nonce generation failed: OSStatus \(status, privacy: .public)")
            throw Failure.randomGenerationFailed(status)
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA-256 digest of the input, hex-encoded, as Apple expects in `request.nonce`.
    /// - Parameter input: the raw nonce string.
    /// - Returns: lowercase hex digest.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
