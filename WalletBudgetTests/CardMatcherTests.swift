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
        // The most specific library entry wins: Reserve beats Sapphire beats Chase.
        XCTAssertEqual(CardMatcher.match("CHASE SAPPHIRE RESERVE"), "Chase Sapphire Reserve")
        XCTAssertEqual(CardMatcher.match("Chase Sapphire Preferred"), "Chase Sapphire")
        XCTAssertEqual(CardMatcher.match("Chase Freedom Unlimited"), "Chase Freedom")
        // A bare bank product still maps to the bank.
        XCTAssertEqual(CardMatcher.match("Chase Slate"), "Chase")
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
