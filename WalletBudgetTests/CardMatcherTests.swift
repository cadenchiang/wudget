import XCTest
@testable import WalletBudget

/// Unit tests for `CardMatcher`, which links a raw imported card string to a `CardLibrary` entry.
final class CardMatcherTests: XCTestCase {
    func testExactMatchIsCanonicalized() {
        XCTAssertEqual(CardMatcher.match("Apple Card"), "Apple Card")
        XCTAssertEqual(CardMatcher.match("apple card"), "Apple Card") // case-insensitive
        XCTAssertEqual(CardMatcher.match("  Visa  "), "Visa")          // trimmed
    }

    func testLibraryNameContainedInRawMatches() {
        XCTAssertEqual(CardMatcher.match("Visa •••• 1234"), "Visa")
        XCTAssertEqual(CardMatcher.match("Bank of America Customized Cash"), "Bank of America")
    }

    func testLongestContainedMatchWins() {
        // "Chase Sapphire" must beat "Chase".
        XCTAssertEqual(CardMatcher.match("CHASE SAPPHIRE RESERVE"), "Chase Sapphire")
        // Plain Chase product still maps to "Chase".
        XCTAssertEqual(CardMatcher.match("Chase Freedom Unlimited"), "Chase")
    }

    func testRawContainedInLibraryNameMatches() {
        XCTAssertEqual(CardMatcher.match("sapphire"), "Chase Sapphire")
    }

    func testUnknownCardReturnsTrimmedRaw() {
        XCTAssertEqual(CardMatcher.match("•••• 9999"), "•••• 9999")
        XCTAssertEqual(CardMatcher.match("My Credit Union"), "My Credit Union")
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(CardMatcher.match(""), "")
        XCTAssertEqual(CardMatcher.match("   "), "")
    }
}
