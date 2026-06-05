import XCTest
@testable import WalletBudget

/// Unit tests for `CardUtilization` (credit-utilization math and health tiers).
final class UserCardTests: XCTestCase {
    /// Utilization is spend over limit; missing or non-positive limits yield nil.
    func testFraction() {
        XCTAssertEqual(CardUtilization.fraction(spent: 300, limit: 1000), 0.3)
        XCTAssertEqual(CardUtilization.fraction(spent: 0, limit: 1000), 0)
        XCTAssertNil(CardUtilization.fraction(spent: 100, limit: nil))
        XCTAssertNil(CardUtilization.fraction(spent: 100, limit: 0))
        XCTAssertEqual(CardUtilization.fraction(spent: -50, limit: 1000), 0) // clamped
    }

    /// Tiers follow credit-score guidance: ≤30% good, ≤50% warning, above high.
    func testTiers() {
        XCTAssertEqual(CardUtilization.tier(for: 0.05), .good)
        XCTAssertEqual(CardUtilization.tier(for: 0.30), .good)
        XCTAssertEqual(CardUtilization.tier(for: 0.31), .warning)
        XCTAssertEqual(CardUtilization.tier(for: 0.50), .warning)
        XCTAssertEqual(CardUtilization.tier(for: 0.51), .high)
        XCTAssertEqual(CardUtilization.tier(for: 1.4), .high)
    }
}
