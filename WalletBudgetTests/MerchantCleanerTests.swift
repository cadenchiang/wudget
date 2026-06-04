import XCTest
@testable import WalletBudget

/// Unit tests for `MerchantCleaner`, which strips trailing store-number suffixes from merchant names.
final class MerchantCleanerTests: XCTestCase {
    func testStripsHashStoreNumber() {
        XCTAssertEqual(MerchantCleaner.clean("Goodwill #110419"), "Goodwill")
        XCTAssertEqual(MerchantCleaner.clean("COSTCO WHSE #0123"), "COSTCO WHSE")
    }

    func testStripsHashWithMixedCharacters() {
        XCTAssertEqual(MerchantCleaner.clean("Shell #A12-3"), "Shell")
        XCTAssertEqual(MerchantCleaner.clean("Target#1234"), "Target") // no space before #
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(MerchantCleaner.clean("  Goodwill #110419  "), "Goodwill")
    }

    func testNameWithoutSuffixIsUnchanged() {
        XCTAssertEqual(MerchantCleaner.clean("Blue Bottle Coffee"), "Blue Bottle Coffee")
        XCTAssertEqual(MerchantCleaner.clean("  Whole Foods  "), "Whole Foods") // only trimmed
    }

    func testBareStoreNumberIsPreserved() {
        // Stripping would leave nothing, so the original is kept.
        XCTAssertEqual(MerchantCleaner.clean("#110419"), "#110419")
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(MerchantCleaner.clean(""), "")
        XCTAssertEqual(MerchantCleaner.clean("   "), "")
    }
}
