import XCTest
@testable import WalletBudget

/// Unit tests for `SupabaseService` (client configuration sanity).
final class SupabaseServiceTests: XCTestCase {
    /// The project URL must point at the expected Supabase project over HTTPS.
    func testProjectURL() {
        XCTAssertEqual(SupabaseService.projectURL.scheme, "https")
        XCTAssertEqual(SupabaseService.projectURL.host, "\(SupabaseService.projectRef).supabase.co")
    }

    /// The anon key must be a three-segment JWT whose payload carries the anon
    /// role for this project (catches pasting the wrong key, e.g. service_role).
    func testAnonKeyIsAnonRoleJWTForThisProject() throws {
        let segments = SupabaseService.anonKey.split(separator: ".")
        XCTAssertEqual(segments.count, 3, "anon key should be a JWT with 3 segments")

        let payload = try XCTUnwrap(decodeBase64URL(String(segments[1])))
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        XCTAssertEqual(json["role"] as? String, "anon", "embedded key must be the anon key, never service_role")
        XCTAssertEqual(json["ref"] as? String, SupabaseService.projectRef)
    }

    /// The shared client must expose an auth client (basic wiring check).
    func testClientIsConfigured() {
        XCTAssertNotNil(SupabaseService.client.auth)
    }

    /// Decodes a base64url segment (JWT padding rules). Returns nil on bad input.
    private func decodeBase64URL(_ input: String) -> Data? {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}
